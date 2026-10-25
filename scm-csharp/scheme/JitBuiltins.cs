namespace scheme;

// Native versions of the builtin lambdas the JIT cannot compile (apply,
// call-with-values, the escape call/cc, continuation procedures), so that
// compiled code calls them without a nested interpreter activation. The
// interpreter keeps running their instructions (CodeList.builtin).
static class JitBuiltins
{
    internal static void Attach(CodeList cl, JitCode code)
    {
        cl.jit = code;
        cl.builtin = true;
    }

    private static readonly Instruction NoPos = new(Opcode.CALLJ, -1);

    // f applied to the arguments in frame[1..], as a tail call at depth.
    internal static object TailApply(VM vm, object f, object[] frame, int depth)
    {
        if (f is Lambda lam)
        {
            if (depth >= Jit.TailDepth) return Rt.MakeTailCall(lam, frame);
            JitCode? jit = lam.cl.jit;
            return jit != null ? jit.Call(vm, lam, frame, depth + 1) : vm.ExecuteNested(lam, frame, depth + 1);
        }
        return Rt.Prim(vm, f, frame, NoPos);
    }

    // f applied to the arguments in frame[1..], as a non-tail call.
    internal static object Apply(VM vm, object f, object[] frame, int depth)
    {
        object r = TailApply(vm, f, frame, depth);
        return r is TailCall ? Rt.Trampoline(vm, r, depth) : r;
    }

    // (apply f a ... list)
    internal sealed class ApplyCode : JitCode
    {
        public override object Call(VM vm, Lambda self, object[] frame, int depth)
        {
            int nargs = frame.Length - 1;
            if (nargs < 1) throw VM.ArityError(self, self.codeArr[0], nargs, " or more");
            object rest = Value.NIL;
            for (int i = nargs; i > 1; i--) rest = new Pair(frame[i], rest);
            List<object> args = VM.FlattenApplyArgs(self.codeArr[1], rest);
            var f = new object[args.Count + 1];
            for (int i = 0; i < args.Count; i++) f[i + 1] = args[i];
            return TailApply(vm, frame[1], f, depth);
        }
    }

    // (call-with-values producer consumer)
    internal sealed class CallWithValuesCode : JitCode
    {
        public override object Call(VM vm, Lambda self, object[] frame, int depth)
        {
            if (frame.Length != 3) throw VM.ArityError(self, self.codeArr[0], frame.Length - 1, "");
            object v;
            try
            {
                v = Apply(vm, frame[1], new object[1], depth);
                if (v is EscapeSignal) return v;
            }
            catch (FrameCapture fc)
            {
                // the interpreter's frame: the return address of SAVE 4
                var env = new object[] { self.env, frame[1], frame[2] };
                fc.Add(new object[] { new ReturnAddress(4, self, env) }, null);
                throw;
            }
            object[] f;
            if (v is Values mv)
            {
                f = new object[mv.values.Length + 1];
                Array.Copy(mv.values, 0, f, 1, mv.values.Length);
            }
            else
            {
                f = new object[] { null!, v };
            }
            return TailApply(vm, frame[2], f, depth);
        }
    }

    // (%call-with-escape-continuation receiver): the continuation belongs
    // to an activation of this call, which a ContinuationJump unwinds to.
    internal sealed class EscapeCode : JitCode
    {
        public override object Call(VM vm, Lambda self, object[] frame, int depth)
        {
            if (frame.Length != 2) throw VM.ArityError(self, self.codeArr[0], frame.Length - 1, "");
            Activation? parent = vm.act;
            var a = new Activation(parent, vm.Sp, depth, false);
            vm.act = a;
            try
            {
                var k = VM.Escape(a, new Continuation(System.Array.Empty<object>(), 0, 0, a));
                object r = Apply(vm, frame[1], new object[] { null!, VM.ContinuationProcedure(k) }, depth);
                return r is EscapeSignal e && e.target == a ? ((object[])e.env)[1] : r;
            }
            catch (ContinuationJump j) when (j.target == a)
            {
                return ((object[])j.env)[1];
            }
            catch (FrameCapture fc)
            {
                fc.Add(System.Array.Empty<object>(), a);
                throw;
            }
            finally
            {
                a.alive = false;
                vm.act = parent;
            }
        }
    }

    // A continuation procedure: unwinds to the activation of its
    // continuation, which continues after the SETCC (ip 3) with env.
    internal sealed class ContinuationCode : JitCode
    {
        public override object Call(VM vm, Lambda self, object[] frame, int depth)
        {
            int n = frame.Length - 1;
            object v = n == 1 ? frame[1] : new Values { values = frame[1..] };
            var k = (Continuation)((object[])self.env)[1];
            var jump = VM.ContinuationJumpFor(k, vm.act!, self, 3, new object[] { self.env, v });
            if (jump is ContinuationJump j) return new EscapeSignal(j.continuation, j.target, j.fn, j.ip, j.env);
            throw jump;
        }
    }
}
