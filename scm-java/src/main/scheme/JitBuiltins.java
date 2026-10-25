package scheme;

import java.util.List;

import scheme.jit.Activation;
import scheme.jit.ContinuationJump;
import scheme.jit.FrameCapture;
import scheme.jit.Jit;
import scheme.jit.JitCode;
import scheme.jit.Rt;
import scheme.jit.TailCall;

// Java versions of the builtin lambdas the JIT cannot compile (apply,
// call-with-values, the escape call/cc, continuation procedures), so that
// compiled code calls them without a nested interpreter activation. The
// interpreter keeps running their instructions (CodeList.builtin).
final class JitBuiltins {
    private JitBuiltins() {}

    static void attach(CodeList cl, JitCode code) {
        cl.jit = code;
        cl.builtin = true;
    }

    // f applied to the arguments in frame[1..], as a tail call at depth.
    static Object tailApply(VM vm, Object f, Object[] frame, int depth) {
        if (f instanceof Lambda) {
            Lambda lam = (Lambda) f;
            if (depth >= Jit.tailDepth) return Rt.tailCall(lam, frame);
            JitCode jit = lam.cl.jit;
            return jit != null ? jit.call(vm, lam, frame, depth + 1) : vm.executeNested(lam, frame, depth + 1);
        }
        return Rt.prim(vm, f, frame, NO_POS);
    }

    // f applied to the arguments in frame[1..], as a non-tail call.
    static Object apply(VM vm, Object f, Object[] frame, int depth) {
        Object r = tailApply(vm, f, frame, depth);
        return r instanceof TailCall ? Rt.trampoline(vm, r, depth) : r;
    }

    private static final Instruction NO_POS = new Instruction(Opcode.CALLJ, -1);

    // (apply f a ... list)
    static final class ApplyCode extends JitCode {
        @Override
        public Object call(VM vm, Lambda self, Object[] frame, int depth) {
            int nargs = frame.length - 1;
            if (nargs < 1) throw VM.arityError(self, self.codeArr[0], nargs, " or more");
            Object rest = Value.NIL;
            for (int i = nargs; i > 1; i--) rest = new Pair(frame[i], rest);
            List<Object> args = VM.flattenApplyArgs(self.codeArr[1], rest);
            Object[] f = new Object[args.size() + 1];
            for (int i = 0; i < args.size(); i++) f[i + 1] = args.get(i);
            return tailApply(vm, frame[1], f, depth);
        }
    }

    // (call-with-values producer consumer)
    static final class CallWithValuesCode extends JitCode {
        @Override
        public Object call(VM vm, Lambda self, Object[] frame, int depth) {
            if (frame.length != 3) throw VM.arityError(self, self.codeArr[0], frame.length - 1, "");
            Object v;
            try {
                v = apply(vm, frame[1], new Object[1], depth);
            } catch (FrameCapture fc) {
                // the interpreter's frame: the return address of SAVE 4
                Object[] env = new Object[] { self.env, frame[1], frame[2] };
                fc.add(new Object[] { new ReturnAddress(4, self, env) }, null);
                throw fc;
            }
            Object[] f;
            if (v instanceof Values) {
                Object[] values = ((Values) v).values;
                f = new Object[values.length + 1];
                System.arraycopy(values, 0, f, 1, values.length);
            } else {
                f = new Object[] { null, v };
            }
            return tailApply(vm, frame[2], f, depth);
        }
    }

    // (%call-with-escape-continuation receiver): the continuation belongs
    // to an activation of this call, which a ContinuationJump unwinds to.
    static final class EscapeCode extends JitCode {
        @Override
        public Object call(VM vm, Lambda self, Object[] frame, int depth) {
            if (frame.length != 2) throw VM.arityError(self, self.codeArr[0], frame.length - 1, "");
            Activation parent = vm.act;
            Activation a = new Activation(parent, vm.sp(), depth, false);
            vm.act = a;
            try {
                Continuation k = VM.escape(a, new Continuation(new Object[0], 0, 0, a));
                return apply(vm, frame[1], new Object[] { null, VM.continuationProcedure(k) }, depth);
            } catch (ContinuationJump j) {
                if (j.target != a) throw j;
                return ((Object[]) j.env)[1];
            } catch (FrameCapture fc) {
                fc.add(new Object[0], a);
                throw fc;
            } finally {
                a.alive = false;
                vm.act = parent;
            }
        }
    }

    // A continuation procedure: unwinds to the activation of its
    // continuation, which continues after the SETCC (ip 3) with env.
    static final class ContinuationCode extends JitCode {
        @Override
        public Object call(VM vm, Lambda self, Object[] frame, int depth) {
            int n = frame.length - 1;
            Object v;
            if (n == 1) {
                v = frame[1];
            } else {
                Values mv = new Values();
                mv.values = java.util.Arrays.copyOfRange(frame, 1, frame.length);
                v = mv;
            }
            Continuation k = (Continuation) ((Object[]) self.env)[1];
            throw VM.continuationJump(k, vm.act, self, 3, new Object[] { self.env, v });
        }
    }
}
