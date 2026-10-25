namespace scheme;

// Runtime support called by compiled code (Jit). The operations mirror the
// corresponding cases of VM.Run.
public static class Rt
{
    public static readonly object True = VM.True;
    public static readonly object False = VM.False;

    // ---- calls ----

    public static object Trampoline(VM vm, object r, int depth)
    {
        while (r is TailCall tc)
        {
            Lambda lam = tc.fn;
            JitCode? jit = lam.cl.jit;
            r = jit != null ? jit.Call(vm, lam, tc.frame, depth + 1)
                            : vm.ExecuteNested(lam, tc.frame, depth + 1);
        }
        return r;
    }

    // a Signal returned to a non-tail call: an EscapeSignal is returned on
    public static object Signal(VM vm, object r, int depth)
    {
        return r is TailCall ? Trampoline(vm, r, depth) : r;
    }

    public static object Interp(VM vm, Lambda lam, object[] frame, int depth)
    {
        return vm.ExecuteNested(lam, frame, depth + 1);
    }

    public static object MakeTailCall(Lambda lam, object[] frame)
    {
        if (Jit.Stats) Jit.statTailCalls++;
        return new TailCall(lam, frame);
    }

    // f applied to frame[1..] when f is not a lambda.
    public static object Prim(VM vm, object f, object[] frame, Instruction ins)
    {
        if (f is not Primitive prim)
            throw new SchemeError(ins.pos, f + " is not a function, cannot apply");
        int n = frame.Length - 1;
        var args = new object[n];
        for (int i = 0; i < n; i++) args[i] = VM.PrimaryValue(frame[i + 1]);
        try
        {
            return prim.Apply(ins.pos, args);
        }
        catch (Exception e) when (e is not SchemeError && e is not FrameCapture && e is not ContinuationJump)
        {
            throw PrimError(e, prim, ins);
        }
    }

    // f applied to args (already primary values) when f is not a lambda
    public static object PrimArgs(object f, object[] args, Instruction ins)
    {
        if (f is not Primitive prim)
            throw new SchemeError(ins.pos, f + " is not a function, cannot apply");
        try
        {
            return prim.Apply(ins.pos, args);
        }
        catch (Exception e) when (e is not SchemeError && e is not FrameCapture && e is not ContinuationJump)
        {
            throw PrimError(e, prim, ins);
        }
    }

    public static Exception PrimError(Exception e, object f, Instruction ins)
    {
        if (e is SchemeError || e is FrameCapture || e is ContinuationJump) return e;
        var prim = (Primitive)f;
        if (e is InvalidCastException ice) return VM.WrongArgumentTypeError(ins.pos, prim.Name(), ice);
        return new SchemeError(ins.pos, "Failed in " + prim.Name() + ": " + e.Message);
    }

    // calls for compact code (Jit.Translator.compact): f applied to frame
    public static object CallF(VM vm, int depth, object f, object[] frame, Instruction ins)
    {
        if (f is Lambda lam)
        {
            JitCode? jit = lam.cl.jit;
            object r = jit != null && depth < Jit.MaxDepth ? jit.Call(vm, lam, frame, depth + 1)
                                                           : vm.ExecuteNested(lam, frame, depth + 1);
            return r is TailCall ? Trampoline(vm, r, depth) : r;
        }
        return Prim(vm, f, frame, ins);
    }

    public static object TailF(VM vm, int depth, object f, object[] frame, Instruction ins)
    {
        if (f is Lambda lam)
        {
            if (depth >= Jit.TailDepth) return MakeTailCall(lam, frame);
            JitCode? jit = lam.cl.jit;
            return jit != null ? jit.Call(vm, lam, frame, depth + 1) : vm.ExecuteNested(lam, frame, depth + 1);
        }
        return Prim(vm, f, frame, ins);
    }

    public static object GCallF(VM vm, int depth, Instruction ins, object[] frame)
    {
        return CallF(vm, depth, GvarCall(vm, ins), frame, ins);
    }

    public static SchemeError Arity(Lambda self, Instruction ins, int nargs)
    {
        return VM.ArityError(self, ins, nargs, "");
    }

    // ARGSDOT: the frame of the fixed arguments and the rest list.
    public static object[] ArgsDot(Lambda self, Instruction ins, object[] frame)
    {
        int fixedArgs = ins.i1, nargs = frame.Length - 1;
        if (nargs < fixedArgs) throw VM.ArityError(self, ins, nargs, " or more");
        object rest = Value.NIL;
        for (int i = nargs; i > fixedArgs; i--) rest = new Pair(frame[i], rest);
        var f = new object[fixedArgs + 2];
        f[0] = self.env;
        Array.Copy(frame, 1, f, 1, fixedArgs);
        f[fixedArgs + 1] = rest;
        return f;
    }

    public static Lambda MakeLambda(object env, List<Instruction> code, string? doc)
    {
        var lambda = new Lambda(env, code);
        if (doc != null) lambda.doc = doc;
        return lambda;
    }

    public static void CheckTerm(VM vm)
    {
        if (vm.thread?.terminated == true) throw new SchemeError("thread terminated");
    }

    public static object NotAProcedure(object f, Instruction ins)
    {
        throw new SchemeError(ins.pos, f + " is not a function, cannot apply");
    }

    // ---- variables ----

    public static object Pv(object v) => VM.PrimaryValue(v);

    public static object Gvar(VM vm, Instruction ins)
    {
        Cell? cell = ins.jitCell;
        if (cell != null && ins.jitCellGeneration == Modules.Generation) return cell.value;
        return Resolve(vm, ins, ins.arg1!).value;
    }

    // the global called by GCALLS/GCALLJ
    public static object GvarCall(VM vm, Instruction ins)
    {
        Cell? cell = ins.jitCell;
        if (cell != null && ins.jitCellGeneration == Modules.Generation) return cell.value;
        return Resolve(vm, ins, ins.arg3!).value;
    }

    private static Cell Resolve(VM vm, Instruction ins, object symbol)
    {
        int generation = Modules.Generation;
        Cell cell = vm.GlobalCell(ins, symbol, (string)ins.arg2!);
        ins.jitCell = cell;
        ins.jitCellGeneration = generation;
        return cell;
    }

    public static void Gset(VM vm, Instruction ins, object v)
    {
        object value = VM.PrimaryValue(v);
        Cell? cell = ins.cachedCell;
        if (cell != null && ins.cachedCellGeneration == vm.modules.CacheGeneration && !Scheme.StrictImports)
        {
            cell.value = value;
            if (value is Lambda lam) lam.name = ins.arg1?.ToString() ?? "?";
            return;
        }
        vm.GlobalSet(ins, value);
    }

    // ---- intrinsics ----

    // boxed small integers, shared like Java's Long.valueOf cache, so that
    // counters and indexes do not allocate
    private const int BoxMin = -128, BoxMax = 1023;
    private static readonly object[] boxes = MakeBoxes();

    private static object[] MakeBoxes()
    {
        var b = new object[BoxMax - BoxMin + 1];
        for (int i = 0; i < b.Length; i++) b[i] = (long)(i + BoxMin);
        return b;
    }

    public static object Box(long r) => (ulong)(r - BoxMin) <= BoxMax - BoxMin ? boxes[r - BoxMin] : r;

    public static bool IsFalse(object v) => v is bool b && !b;

    public static object IsNull(object v) => v == Value.NIL ? True : False;

    public static object IsPairO(object v) => Value.IsPair(v) ? True : False;

    public static bool IsPair(object v) => Value.IsPair(v);

    public static object Not(object v) => IsFalse(v) ? True : False;

    public static bool EqZ(object a, object b) => PrimitiveEqP.Eq(a, b);

    public static bool EqvZ(object a, object b) => PrimitiveEqvP.Eqv(a, b);

    public static object Eq(object a, object b) => PrimitiveEqP.Eq(a, b) ? True : False;

    public static object Eqv(object a, object b) => PrimitiveEqvP.Eqv(a, b) ? True : False;

    public static Pair AsPair(object v) => Value.AsPair(v);

    public static object Car(object v) => Value.AsPair(v).car;

    public static object Cdr(object v) => Value.AsPair(v).cdr;

    public static object Cons(object a, object b) => new Pair(a, b);

    public static object Add(object ia, object ib)
    {
        if (ia is long a && ib is long b)
        {
            long r = unchecked(a + b);
            if (((a ^ r) & (b ^ r)) >= 0) return Box(r);
        }
        return VM.Add2(ia, ib);
    }

    public static object Sub(object ia, object ib)
    {
        if (ia is long a && ib is long b)
        {
            long r = unchecked(a - b);
            if (((a ^ b) & (a ^ r)) >= 0) return Box(r);
        }
        return VM.Sub2(ia, ib);
    }

    public static object Mul(object ia, object ib)
    {
        if (ia is long a && ib is long b)
        {
            long high = Math.BigMul(a, b, out long r);
            if ((high == 0 && r >= 0) || (high == -1 && r < 0)) return Box(r);
        }
        return VM.Mul2(ia, ib);
    }

    public static object Div(object ia, object ib, Instruction ins) => VM.Div2(ins.pos, ia, ib);

    public static object Negate(object ia) => VM.Negate(ia);

    public static object AddImm(object v, long imm)
    {
        if (v is long a)
        {
            long r = unchecked(a + imm);
            if (((a ^ r) & (imm ^ r)) >= 0) return Box(r);
        }
        return VM.Add2(v, imm);
    }

    public static object SubImm(object v, long imm)
    {
        if (v is long a)
        {
            long r = unchecked(a - imm);
            if (((a ^ imm) & (a ^ r)) >= 0) return Box(r);
        }
        return VM.Sub2(v, imm);
    }

    public static bool NumEqZ(object ia, object ib, Instruction ins) =>
        ia is long a && ib is long b ? a == b : VM.Compare2(Opcode.NUM_EQ, ins.pos, ia, ib);
    public static bool NumLtZ(object ia, object ib, Instruction ins) =>
        ia is long a && ib is long b ? a < b : VM.Compare2(Opcode.NUM_LT, ins.pos, ia, ib);
    public static bool NumGtZ(object ia, object ib, Instruction ins) =>
        ia is long a && ib is long b ? a > b : VM.Compare2(Opcode.NUM_GT, ins.pos, ia, ib);
    public static bool NumLteZ(object ia, object ib, Instruction ins) =>
        ia is long a && ib is long b ? a <= b : VM.Compare2(Opcode.NUM_LTE, ins.pos, ia, ib);
    public static bool NumGteZ(object ia, object ib, Instruction ins) =>
        ia is long a && ib is long b ? a >= b : VM.Compare2(Opcode.NUM_GTE, ins.pos, ia, ib);

    public static object NumEq(object a, object b, Instruction ins) => NumEqZ(a, b, ins) ? True : False;
    public static object NumLt(object a, object b, Instruction ins) => NumLtZ(a, b, ins) ? True : False;
    public static object NumGt(object a, object b, Instruction ins) => NumGtZ(a, b, ins) ? True : False;
    public static object NumLte(object a, object b, Instruction ins) => NumLteZ(a, b, ins) ? True : False;
    public static object NumGte(object a, object b, Instruction ins) => NumGteZ(a, b, ins) ? True : False;

    // An arithmetic intrinsic with other than the inlined argument count.
    public static object Nary(object[] args, Instruction ins)
    {
        Primitive prim = ins.opcode switch
        {
            Opcode.ADD => VM.s_primitiveAdd,
            Opcode.SUB => VM.s_primitiveSub,
            Opcode.MUL => VM.s_primitiveMul,
            Opcode.DIV => VM.s_primitiveDiv,
            Opcode.NUM_EQ => VM.s_primitiveNumEq,
            Opcode.NUM_LT => VM.s_primitiveNumLt,
            Opcode.NUM_GT => VM.s_primitiveNumGt,
            Opcode.NUM_LTE => VM.s_primitiveNumLte,
            _ => VM.s_primitiveNumGte
        };
        return prim.Apply(ins.pos, args);
    }

    public static object VectorRef(object v, object idx, Instruction ins)
    {
        var vec = Value.AsVector(v);
        int i = IntegerMath.ToInt(idx);
        if (i < 0 || i >= vec.Length)
            throw new SchemeError(ins.pos, "vector-ref: index out of range: ~a", idx);
        return vec[i];
    }

    public static object VrefConst(object v, int i, Instruction ins)
    {
        var vec = Value.AsVector(v);
        if (i >= vec.Length)
            throw new SchemeError(ins.pos, "vector-ref: index out of range: ~a", (long)i);
        return vec[i];
    }

    public static object VectorSet(object v, object idx, object val, Instruction ins)
    {
        var vec = Value.AsVector(v);
        int i = IntegerMath.ToInt(idx);
        if (i < 0 || i >= vec.Length)
            throw new SchemeError(ins.pos, "vector-set!: index out of range: ~a", idx);
        vec[i] = val;
        return new Values();
    }

    public static object Cxr(object v, int path)
    {
        for (int p = path; p != 1; p >>= 1)
            v = (p & 1) != 0 ? Value.AsPair(v).cdr : Value.AsPair(v).car;
        return v;
    }

    // ---- unwinding ----

    // The exception filter of compiled code: true for an error raised in
    // self at instruction ip (handled by Unwind). A capture from a callee
    // gets this frame's part of the stack added (none for a tail call) and
    // passes on, as does a continuation jump.
    public static bool Filter(Exception e, Lambda self, int ip, object env, object[] slots)
    {
        if (e is FrameCapture fc)
        {
            Instruction ins = self.codeArr[ip];
            if (ins.opcode == Opcode.CALLS || ins.opcode == Opcode.GCALLS)
            {
                int d = self.cl.depths![ip];
                int below = d - ins.i1 - (ins.opcode == Opcode.CALLS ? 1 : 0);
                var seg = new object[below + 1];
                Array.Copy(slots, seg, below);
                seg[below] = new ReturnAddress(ip + 1, self, env);
                fc.Add(seg, null);
            }
            return false;
        }
        return e is SchemeError || e is InvalidCastException;
    }

    // An error raised in compiled self at instruction ip: calls the
    // innermost exception handler in place or, with none, returns the
    // FrameCapture that unwinds to the root.
    public static Exception Unwind(Exception e, VM vm, Lambda self, int ip, object env, object[] slots, int depth)
    {
        SchemeError err = e is InvalidCastException ice ? VM.CastError(self, ip + 1, ice) : (SchemeError)e;
        int d = self.cl.depths![ip];
        var stack = slots[..d];
        if (vm.exceptionHandlers != Value.NIL) return RaiseInPlace(vm, err, stack, depth);
        if (Jit.Stats) Jit.statErrors++;
        var fc = new FrameCapture(err, self, ip + 1, env, 0);
        fc.Add(stack, null);
        return fc;
    }

    // VM.SetupRaiseCall for compiled code: the handlers are called on top
    // of the raising frame, whose operand stack is stack.
    private static Exception RaiseInPlace(VM vm, SchemeError err, object[] stack, int depth)
    {
        object condition = (object?)err.errorObject ?? new ErrorObject(err.Message, Array.Empty<object>());
        for (;;)
        {
            var hl = Value.AsPair(vm.exceptionHandlers);
            object handler = hl.car;
            vm.exceptionHandlers = hl.cdr;
            ErrorObject? returned;
            if (handler is Lambda lam)
            {
                var frame = new object[] { null!, condition };
                try
                {
                    JitCode? jit = lam.cl.jit;
                    object r = jit != null ? Trampoline(vm, jit.Call(vm, lam, frame, depth + 1), depth)
                                           : vm.ExecuteNested(lam, frame, depth + 1);
                    if (r is EscapeSignal escape) return escape.ToJump();
                }
                catch (FrameCapture fc)
                {
                    var seg = new object[stack.Length + 1];
                    Array.Copy(stack, seg, stack.Length);
                    seg[stack.Length] = new ReturnAddress(0, vm.raiseReturnedLambda, Value.NIL);
                    fc.Add(seg, null);
                    return fc;
                }
                returned = new ErrorObject("raise: exception handler returned", Array.Empty<object>());
            }
            else if (handler is Primitive prim)
            {
                try
                {
                    prim.Apply(null, new[] { condition });
                    returned = new ErrorObject("raise: exception handler returned", new[] { condition });
                }
                catch (SchemeError inner)
                {
                    returned = null;
                    condition = (object?)inner.errorObject ?? new ErrorObject(inner.Message, Array.Empty<object>());
                    if (vm.exceptionHandlers == Value.NIL) return Fatal(vm, inner, stack);
                }
            }
            else
            {
                return Fatal(vm, new SchemeError((SourcePos?)null,
                    "with-exception-handler: handler is not a procedure"), stack);
            }
            if (returned != null)
            {
                if (vm.exceptionHandlers == Value.NIL)
                    return Fatal(vm, new SchemeError(null, returned), stack);
                condition = returned;
            }
        }
    }

    private static FrameCapture Fatal(VM vm, SchemeError e, object[] stack)
    {
        var fc = new FrameCapture(e, vm.raiseReturnedLambda, 1, Value.NIL, 0);
        fc.Add(stack, null);
        return fc;
    }
}
