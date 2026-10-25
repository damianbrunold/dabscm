using System.Numerics;

namespace scheme;

public class VM
{
    internal readonly Modules modules;

    // The VM state. While Execute runs it lives in Execute's locals; these
    // fields hold it only where code outside the dispatch loop needs it
    // (SetupRaiseCall, ExtractCallStack) and between executes.
    private Lambda? fn;
    private int ip;
    private object env = Value.NIL;

    // Opt A: array-based stack (eliminates one Pair allocation per Push)
    private object[] stackArr = new object[512];
    private int sp = 0;

    private int nargs = 0;
    private int flattened = 0;

    public Dictionary<string, int> call_counts = new();
    public object winders = Value.NIL;
    public object exceptionHandlers = Value.NIL;

    [ThreadStatic]
    public static VM? Current;

    internal readonly Lambda raiseReturnedLambda;

    // Static primitive instances for intrinsic fallbacks (variable-arity / edge-case paths)
    internal static readonly PrimitiveAdd s_primitiveAdd = new();
    internal static readonly PrimitiveSub s_primitiveSub = new();
    internal static readonly PrimitiveMul s_primitiveMul = new();
    internal static readonly PrimitiveDiv s_primitiveDiv = new();
    internal static readonly PrimitiveNumequal s_primitiveNumEq = new();
    internal static readonly PrimitiveNumless s_primitiveNumLt = new();
    internal static readonly PrimitiveNumgreater s_primitiveNumGt = new();
    internal static readonly PrimitiveNumlessequal s_primitiveNumLte = new();
    internal static readonly PrimitiveNumgreaterequal s_primitiveNumGte = new();

    // The Scheme name of an opcode that can fail with a wrong argument type,
    // for the error message; null for the VM's internal opcodes.
    internal static string? OpcodeErrorName(Opcode op) => op switch
    {
        Opcode.CAR or Opcode.LVAR_CAR => "car",
        Opcode.CDR or Opcode.LVAR_CDR => "cdr",
        Opcode.CONS => "cons",
        Opcode.IS_NULL => "null?",
        Opcode.IS_PAIR => "pair?",
        Opcode.NOT => "not",
        Opcode.ADD or Opcode.LVAR_ADD_IMM => "+",
        Opcode.SUB or Opcode.LVAR_SUB_IMM => "-",
        Opcode.MUL => "*",
        Opcode.DIV => "/",
        Opcode.NUM_EQ => "=",
        Opcode.NUM_LT => "<",
        Opcode.NUM_GT => ">",
        Opcode.NUM_LTE => "<=",
        Opcode.NUM_GTE => ">=",
        Opcode.EQ_P => "eq?",
        Opcode.EQV_P => "eqv?",
        Opcode.VECTOR_REF or Opcode.LVAR_VREF => "vector-ref",
        Opcode.VECTOR_SET => "vector-set!",
        Opcode.FLATTEN_APPLY => "apply",
        _ => null
    };

    // "Failed in <name>: wrong argument type", with the offending value as
    // irritant when the cast site reported it (WrongTypeException).
    internal static SchemeError WrongArgumentTypeError(SourcePos? pos, string name, InvalidCastException e)
    {
        string message = "Failed in " + name + ": wrong argument type";
        if (e is not WrongTypeException wt)
            return new SchemeError(pos, new ErrorObject(message, Array.Empty<object>()));
        if (WrongTypeException.IsHostValue(wt.Value))
            message += " (host " + wt.Value.GetType().Name + ", not a Scheme " + wt.Expected + ")";
        return new SchemeError(pos, new ErrorObject(message, new[] { wt.Value }));
    }

    private static double VmToReal(object v)
    {
        if (v is long l) return (double)l;
        if (Value.IsBigInteger(v)) return IntegerMath.ToDouble(v);
        if (v is Rational r) return r.ToDouble();
        return (double)v;
    }

    // Opt C: per-VM pool of exact-size argument arrays (eliminates new object[n] per primitive call)
    private const int MAX_POOL_SIZE = 16;
    private const int MAX_POOL_DEPTH = 8;
    private readonly object[]?[] pool = new object[]?[(MAX_POOL_SIZE + 1) * MAX_POOL_DEPTH];
    private readonly int[] poolDepths = new int[MAX_POOL_SIZE + 1];

    public VM(Modules modules)
    {
        this.modules = modules;
        this.raiseReturnedLambda = new Lambda(Value.NIL,
            new List<Instruction> { new Instruction(Opcode.HANDLER_RETURNED) })
            { name = "raise-returned" };
    }

    private object[] RentArgs(int n)
    {
        if (n <= MAX_POOL_SIZE && poolDepths[n] > 0)
            return pool[n * MAX_POOL_DEPTH + --poolDepths[n]]!;
        return new object[n];
    }

    private void ReturnArgs(object[] arr)
    {
        int n = arr.Length;
        if (n <= MAX_POOL_SIZE && poolDepths[n] < MAX_POOL_DEPTH)
        {
            Array.Clear(arr, 0, n);
            pool[n * MAX_POOL_DEPTH + poolDepths[n]++] = arr;
        }
    }

    private void SetupRaiseCall(object condition)
    {
        var hl = Value.AsPair(exceptionHandlers);
        var handler = hl.car;
        exceptionHandlers = hl.cdr;

        if (handler is Lambda lam)
        {
            Push(new ReturnAddress(0, raiseReturnedLambda, Value.NIL));
            Push(condition);
            nargs = 1;
            fn = lam;
            ip = 0;
            env = lam.env;
        }
        else if (handler is Primitive prim)
        {
            try { prim.Apply(null, new[] { condition }); }
            catch (SchemeError inner)
            {
                var innerCond = (object?)inner.errorObject ?? new ErrorObject(inner.Message, Array.Empty<object>());
                if (exceptionHandlers != Value.NIL)
                    SetupRaiseCall(innerCond);
                else
                {
                    if (inner.schemeCallStack == null) inner.schemeCallStack = ExtractCallStack();
                    throw;
                }
                return;
            }
            var errCond = new ErrorObject("raise: exception handler returned", new[] { condition });
            if (exceptionHandlers != Value.NIL)
                SetupRaiseCall(errCond);
            else
                throw new SchemeError(null, errCond);
        }
        else
        {
            throw new SchemeError((SourcePos?)null, "with-exception-handler: handler is not a procedure");
        }
    }

    // An environment is a chain of frames: object[] with the parent
    // environment in slot 0 and the frame's variables from slot 1.
    private static object Getenv(object env, int frame, int variable)
    {
        var f = (object[])env;
        for (int i = 0; i < frame; i++) f = (object[])f[0];
        return f[variable + 1];
    }

    private static void Setenv(object env, int frame, int variable, object value)
    {
        var f = (object[])env;
        for (int i = 0; i < frame; i++) f = (object[])f[0];
        f[variable + 1] = value;
    }

    // The dispatch loop pushes without a bounds check: an instruction
    // pushes at most one value and jumps only forward, so the rest of the
    // current function needs at most one slot per remaining instruction.
    // That room is made whenever a function is entered or returned to, at
    // backward jumps (only possible in code from set-code!) and by the
    // instructions that push many values.
    private object[] EnsureStack(object[] stack, int needed)
    {
        if (needed <= stack.Length) return stack;
        var bigger = new object[Math.Max(stack.Length * 2, needed)];
        Array.Copy(stack, bigger, stack.Length);
        stackArr = bigger;
        return bigger;
    }

    // Opt A: array-based stack; Push for the code outside the dispatch loop
    private void Push(object value)
    {
        stackArr = EnsureStack(stackArr, sp + 1);
        stackArr[sp++] = value;
    }

    // Booleans boxed once: the VM pushes these instead of boxing Value.T
    // and Value.F at every test (eq? compares booleans by value).
    internal static readonly object True = Value.T;
    internal static readonly object False = Value.F;

    internal static bool IsFalse(object value) => value is bool b && !b;

    internal static object PrimaryValue(object value)
    {
        if (Value.IsValues(value))
        {
            var vals = Value.AsValues(value).values;
            if (vals.Length == 0) return value; // empty values = unspecified, pass through
            return vals[0];
        }
        return value;
    }

    private List<SchemeCallFrame> ExtractCallStack()
    {
        var frames = new List<SchemeCallFrame>();
        SourcePos? currentPos = (fn != null && ip > 0 && ip - 1 < fn.codeArr.Length)
            ? fn.codeArr[ip - 1].pos : null;
        frames.Add(new SchemeCallFrame(fn?.name, currentPos));
        for (int i = sp - 1; i >= 0; i--)
            if (stackArr[i] is ReturnAddress addr)
            {
                SourcePos? callPos = (addr.ip > 0 && addr.ip - 1 < addr.fn.codeArr.Length)
                    ? addr.fn.codeArr[addr.ip - 1].pos : null;
                frames.Add(new SchemeCallFrame(addr.fn.name, callPos));
            }
        return frames;
    }

    // Cold paths of the dispatch loop, kept out of Execute so that the JIT
    // compiles the loop itself well.

    // The binding cell of a global variable, cached in the instruction
    // (GVAR, GCALLS, GCALLJ).
    internal Cell GlobalCell(Instruction instruction, object symbolObj, string moduleName)
    {
        var cell = instruction.cachedCell;
        if (cell != null && instruction.cachedCellGeneration == modules.CacheGeneration)
            return cell;
        try
        {
            var symbol = Value.AsSymbol(symbolObj);
            var module = modules.GetModuleRequired(instruction.pos, moduleName);
            var resolved = module.ResolveCell(symbol);
            if (resolved == null)
                throw new SchemeError(instruction.pos, module.Name + ": ~a is not bound", symbol);
            instruction.cachedCell = resolved;
            instruction.cachedCellGeneration = modules.CacheGeneration;
            return resolved;
        }
        catch (SchemeError)
        {
            throw;
        }
        catch (Exception)
        {
            throw new SchemeError(instruction.pos, "internal error");
        }
    }

    internal void GlobalSet(Instruction instruction, object value)
    {
        var module = modules.GetModuleRequired(instruction.pos, (string) instruction.arg2!);
        var symbol = Value.AsSymbol(instruction.arg1!);
        if (Scheme.StrictImports && module.Name == "user program")
        {
            if (module.Provenance.TryGetValue(symbol, out var origin) &&
                origin != module.Name && origin != "scm core")
            {
                throw new SchemeError(instruction.pos,
                    "program: cannot redefine imported symbol '~a' from '~a'",
                    symbol, origin);
            }
        }
        module.Bind(symbol, value);
        instruction.cachedCell = module.ResolveCell(symbol);
        instruction.cachedCellGeneration = modules.CacheGeneration;
        if (Value.IsLambda(value))
        {
            Value.AsLambda(value).name = instruction.arg1?.ToString() ?? "?";
        }
    }

    internal static SchemeError ArityError(Lambda fn, Instruction instruction, int nargs, string expected)
    {
        return new SchemeError(
            instruction.pos,
            (fn.name != null ? fn.name + " " : "") +
            "Wrong number of arguments: "
            + instruction.arg1! + expected + " expected, "
            + nargs + " supplied"
        );
    }

    // Applies the primitive f to the argcount values at stack[sp..], which
    // the caller has popped; their slots are cleared.
    private object ApplyPrimitive(object f, SourcePos? pos, object[] stack, int sp, int argcount)
    {
        var prim = Value.AsPrimitive(f);
        // Opt C: use pooled arg arrays
        object[] args = RentArgs(argcount);
        for (int i = 0; i < argcount; i++)
        {
            args[i] = PrimaryValue(stack[sp + i]);
            stack[sp + i] = null!;
        }
        object result;
        try
        {
            result = prim.Apply(pos, args);
        }
        catch (SchemeError)
        {
            ReturnArgs(args);
            throw;
        }
        catch (InvalidCastException e)
        {
            ReturnArgs(args);
            throw WrongArgumentTypeError(pos, prim.Name(), e);
        }
        catch (Exception e)
        {
            ReturnArgs(args);
            throw new SchemeError(pos, "Failed in " + prim.Name() + ": " + e.Message);
        }
        // If a primitive stored the args array directly in the result (e.g. `values`),
        // clone it before clearing so the result isn't corrupted.
        if (result is Values pooledVals && object.ReferenceEquals(pooledVals.values, args))
            pooledVals.values = (object[])args.Clone();
        ReturnArgs(args);
        return result;
    }

    // An arithmetic intrinsic with other than the inlined argument count:
    // the n values at stack[sp..], popped by the caller.
    private object ApplyIntrinsic(Primitive prim, SourcePos? pos, object[] stack, int sp, int n)
    {
        object[] iarr = RentArgs(n);
        Array.Copy(stack, sp, iarr, 0, n);
        object result = prim.Apply(pos, iarr);
        ReturnArgs(iarr);
        return result;
    }

    // The two-argument arithmetic beyond fixnums without overflow.
    internal static object Add2(object ia, object ib)
    {
        if (Value.IsInteger(ia) && Value.IsInteger(ib)) return IntegerMath.GenericAdd(ia, ib);
        if (ia is double || ib is double)
        {
            if (ia is Complex || ib is Complex) return Complex.Add(ia, ib);
            return VmToReal(ia) + VmToReal(ib);
        }
        if (ia is Complex || ib is Complex) return Complex.Add(ia, ib);
        return Rational.Add(ia, ib);
    }

    internal static object Sub2(object ia, object ib)
    {
        if (Value.IsInteger(ia) && Value.IsInteger(ib)) return IntegerMath.GenericSub(ia, ib);
        if (ia is double || ib is double)
        {
            if (ia is Complex || ib is Complex) return Complex.Sub(ia, ib);
            return VmToReal(ia) - VmToReal(ib);
        }
        if (ia is Complex || ib is Complex) return Complex.Sub(ia, ib);
        return Rational.Sub(ia, ib);
    }

    internal static object Mul2(object ia, object ib)
    {
        if (Value.IsInteger(ia) && Value.IsInteger(ib)) return IntegerMath.GenericMul(ia, ib);
        if (ia is double || ib is double)
        {
            if (ia is Complex || ib is Complex) return Complex.Mul(ia, ib);
            return VmToReal(ia) * VmToReal(ib);
        }
        if (ia is Complex || ib is Complex) return Complex.Mul(ia, ib);
        return Rational.Mul(ia, ib);
    }

    internal static object Div2(SourcePos? pos, object ia, object ib)
    {
        if (ia is long ial && ib is long ibl)
        {
            if (ibl == 0) throw new SchemeError(pos, "/: Division by zero");
            return Rational.Div(ial, ibl);
        }
        if (ia is double || ib is double)
        {
            if (ia is Complex || ib is Complex) return Complex.Div(ia, ib);
            double dib = VmToReal(ib);
            if (dib == 0.0) throw new SchemeError(pos, "/: Division by ~s", dib);
            return VmToReal(ia) / dib;
        }
        if (ia is Complex || ib is Complex) return Complex.Div(ia, ib);
        return Rational.Div(ia, ib);
    }

    internal static object Negate(object ia)
    {
        if (ia is long ial) return IntegerMath.Negate(ial);
        if (Value.IsBigInteger(ia)) return IntegerMath.GenericNegate(ia);
        if (ia is double iad) return -iad;
        if (ia is Complex) return Complex.Negate(ia);
        return Rational.Sub(0L, ia);
    }

    // =, <, >, <=, >= on two numbers that are not both fixnums.
    internal static bool Compare2(Opcode op, SourcePos? pos, object ia, object ib)
    {
        if (op == Opcode.NUM_EQ)
        {
            if (Value.IsInteger(ia) && Value.IsInteger(ib)) return IntegerMath.GenericEquals(ia, ib);
            if (ia is double iad && ib is double ibd) return iad == ibd;
            if (ia is Complex || ib is Complex) return Complex.NumericEquals(ia, ib);
            return Primitive.MixedNumericEquals(ia, ib);
        }
        if (Value.IsInteger(ia) && Value.IsInteger(ib))
        {
            int c = IntegerMath.Compare(ia, ib);
            return op switch
            {
                Opcode.NUM_LT => c < 0,
                Opcode.NUM_GT => c > 0,
                Opcode.NUM_LTE => c <= 0,
                _ => c >= 0
            };
        }
        if (ia is Complex || ib is Complex)
            throw new SchemeError(pos, OpcodeErrorName(op) + ": complex numbers are not ordered");
        return op switch
        {
            Opcode.NUM_LT => Primitive.NumLess(ia, ib),
            Opcode.NUM_GT => Primitive.NumGreater(ia, ib),
            Opcode.NUM_LTE => Primitive.NumLessEq(ia, ib),
            _ => Primitive.NumGreaterEq(ia, ib)
        };
    }

    // The arguments of (apply f a ... list) from its rest argument.
    internal static List<object> FlattenApplyArgs(Instruction instruction, object restObj)
    {
        List<object> args = new();
        if (restObj == Value.NIL)
            throw new SchemeError(instruction.pos, "apply: not enough arguments");
        object pair = Value.AsPair(restObj);
        while (pair != Value.NIL)
        {
            if (Value.AsPair(pair).cdr == Value.NIL)
            {
                if (!Value.IsPair(Value.AsPair(pair).car) && !Value.IsNil(Value.AsPair(pair).car))
                    throw new SchemeError(instruction.pos, "apply: last argument must be a list");
                pair = Value.AsPair(pair).car == Value.NIL ? Value.NIL : Value.AsPair(Value.AsPair(pair).car);
                while (pair != Value.NIL)
                {
                    args.Add(Value.AsPair(pair).car);
                    pair = Value.AsPair(pair).cdr;
                }
                break;
            }
            else
            {
                args.Add(Value.AsPair(pair).car);
                pair = Value.AsPair(pair).cdr;
            }
        }
        return args;
    }

    // The code of a continuation procedure: its frame's parent holds the
    // Continuation.
    internal static readonly CodeList CONTINUATION_CODE = MakeContinuationCode();

    private static CodeList MakeContinuationCode()
    {
        var code = new CodeList
        {
            new Instruction(Opcode.ARGMV),
            new Instruction(Opcode.LVAR, 1, 0),
            new Instruction(Opcode.SETCC),
            new Instruction(Opcode.LVAR, 0, 0),
            new Instruction(Opcode.RETURN)
        };
        JitBuiltins.Attach(code, new JitBuiltins.ContinuationCode());
        return code;
    }

    internal static Lambda ContinuationProcedure(Continuation k)
    {
        // Opt B: env frame must be object[]
        return new Lambda(new object[] { Value.NIL, k }, CONTINUATION_CODE);
    }

    // The continuation of the current stack as a procedure (CC).
    private static Lambda CaptureContinuation(object[] stack, int sp)
    {
        return ContinuationProcedure(new Continuation(stack, sp));
    }

    // An escape continuation of the nested activation a (CC/ECC). The
    // activation keeps it (weakly) to turn it into a full continuation if
    // the activation is unwound into the root (rebuild).
    private static Lambda CaptureEscape(Activation a, object[] stack, int sp)
    {
        return ContinuationProcedure(Escape(a, new Continuation(stack, a.Base + 1, sp, a)));
    }

    internal static Continuation Escape(Activation a, Continuation k)
    {
        if (Jit.Stats) Jit.statEscapes++;
        var escapes = a.escapes ??= new List<WeakReference<Continuation>>();
        if (escapes.Count >= 64 && System.Numerics.BitOperations.PopCount((uint)escapes.Count) == 1)
            escapes.RemoveAll(r => !r.TryGetTarget(out _));
        escapes.Add(new WeakReference<Continuation>(k));
        return k;
    }

    // SETCC of a continuation that belongs to another activation than a.
    internal static Exception ContinuationJumpFor(Continuation k, Activation a, Lambda fn, int ip, object env)
    {
        if (Jit.Stats) Jit.statJumps++;
        if (k.act == null) return new ContinuationJump(k, a.NearestRoot(), fn, ip, env);
        if (!k.act.alive)
            return new SchemeError((SourcePos?)null,
                "continuation invoked outside of its extent: it was captured as an escape "
                + "continuation across compiled code (SCM_JIT=off disables the JIT)");
        return new ContinuationJump(k, k.act, fn, ip, env);
    }

    // CC in a nested activation: unwinds to the root activation, which
    // rebuilds the stack and executes the CC at ip again.
    private static FrameCapture CaptureRequest(Activation a, Lambda fn, int ip, object env, int nargs,
                                               object[] stack, int sp)
    {
        if (Jit.Stats) Jit.statCaptures++;
        var fc = new FrameCapture(FrameCapture.CAPTURE, fn, ip, env, nargs);
        fc.Add(stack[(a.Base + 1)..sp], a);
        return fc;
    }

    // The escape continuations of the unwound activation a become full
    // continuations: the stack below a's segment (stack[0..sp]) is what it
    // was when they were captured, the callers being suspended since.
    private static void PromoteEscapes(Activation a, object[] stack, int sp)
    {
        if (a.escapes == null) return;
        foreach (var r in a.escapes)
        {
            if (!r.TryGetTarget(out var k) || k.act != a) continue;
            var full = new object[sp + k.stack.Length];
            Array.Copy(stack, 0, full, 0, sp);
            Array.Copy(k.stack, 0, full, sp, k.stack.Length);
            k.stack = full;
            k.act = null;
        }
        a.escapes = null;
    }

    // A compiled lambda called from the interpreter with the argcount
    // values at stack[sp..] (popped by the caller). retIp >= 0 for a
    // non-tail call: its return address, should the callee be unwound.
    private object CallJit(Lambda lam, object[] stack, int sp, int argcount, int depth,
                           int retIp, Lambda? fn, object? env)
    {
        var frame = new object[argcount + 1];
        for (int i = 0; i < argcount; i++)
        {
            frame[i + 1] = stack[sp + i];
            stack[sp + i] = null!;
        }
        this.sp = sp;
        try
        {
            object r = lam.cl.jit!.Call(this, lam, frame, depth + 1);
            if (r is Signal)
            {
                r = Rt.Signal(this, r, depth);
                if (r is EscapeSignal e) throw e.ToJump();
            }
            return r;
        }
        catch (FrameCapture fc)
        {
            if (retIp >= 0) fc.Add(new object[] { new ReturnAddress(retIp, fn!, env!) }, null);
            throw;
        }
    }

    // "wrong argument type" for an InvalidCastException in fn's instruction
    // before ip (no opcode changes ip or fn before it can fail a cast).
    internal static SchemeError CastError(Lambda? fn, int ip, InvalidCastException e)
    {
        Instruction? failed = fn != null && ip > 0 && ip <= fn.codeArr.Length ? fn.codeArr[ip - 1] : null;
        string name = failed == null ? "VM"
            : failed.opcode == Opcode.CXR ? (string)failed.arg2!
            : OpcodeErrorName(failed.opcode) ?? failed.opcode + " instruction";
        return WrongArgumentTypeError(failed?.pos, name, e);
    }

    // The current activation of the interpreter loop (or of a JitBuiltins
    // escape) and the thread it runs for.
    internal Activation? act;
    public SchemeThread? thread;

    internal int Sp => sp;

    public object Execute(Lambda func)
    {
        VM? savedCurrent = VM.Current;
        VM.Current = this;
        Activation? savedAct = act;
        try
        {
            if (SchemeThread.CurrentThread == null)
            {
                var primordial = new SchemeThread(null, modules);
                primordial.name = Value.Intern("primordial");
                primordial.state = SchemeThreadState.STARTED;
                SchemeThread.CurrentThread = primordial;
            }
            thread = SchemeThread.CurrentThread;
            object savedWinders = winders;
            object savedExceptionHandlers = exceptionHandlers;
            var a = new Activation(savedAct, sp, 0, true);
            act = a;
            Push(new ReturnAddress(func.code.Count, func, this.env));
            try
            {
                return Run(a, func, this.env, 0, sp, savedWinders, savedExceptionHandlers);
            }
            finally
            {
                a.alive = false;
            }
        }
        finally
        {
            act = savedAct;
            VM.Current = savedCurrent;
        }
    }

    // A lambda called from compiled code (or Rt), run by a nested
    // activation of the interpreter loop above the current stack.
    public object ExecuteNested(Lambda lam, object[] frame, int depth)
    {
        CodeList cl = lam.cl;
        if (Jit.Stats) { Jit.statNested++; Jit.CountNested(cl); }
        if (cl.calls++ == Jit.Threshold) Jit.Compile(cl);
        Activation? parent = act;
        var a = new Activation(parent, this.sp, depth, false);
        act = a;
        int n = frame.Length - 1;
        Instruction[] code = lam.codeArr;
        int sp = this.sp;
        object[] stack = EnsureStack(stackArr, sp + n + 1 + code.Length);
        stack[sp++] = new ReturnAddress(code.Length, lam, lam.env);
        Array.Copy(frame, 1, stack, sp, n);
        sp += n;
        try
        {
            return Run(a, lam, lam.env, n, sp, null, null);
        }
        finally
        {
            a.alive = false;
            act = parent;
        }
    }

    // The interpreter loop of activation act, starting fn at instruction 0
    // with the stack up to sp. savedWinders and savedExceptionHandlers are
    // the root's, restored when an error leaves it.
    private object Run(Activation act, Lambda fn, object env, int nargs, int sp,
                       object? savedWinders, object? savedExceptionHandlers)
    {
        int depth = act.depth;
        Instruction[] code = fn.codeArr;
        int ip = 0;
        object[] stack = EnsureStack(stackArr, sp + code.Length);
        for (;;)
        {
        Exception pending;
        try
        {
        while (ip < code.Length)
        {
            Instruction instruction = code[ip++];
            switch (instruction.opcode)
            {
                case Opcode.LVAR:
                    stack[sp] = Getenv(env, instruction.i1, instruction.i2); sp++;
                    break;

                case Opcode.LSET:
                    Setenv(env, instruction.i1, instruction.i2, PrimaryValue(stack[sp - 1]));
                    break;

                case Opcode.GVAR:
                    stack[sp] = GlobalCell(instruction, instruction.arg1!, (string)instruction.arg2!).value; sp++;
                    break;

                case Opcode.GSET: {
                    object value = PrimaryValue(stack[sp - 1]);
                    var cachedCell = instruction.cachedCell;
                    if (cachedCell != null
                        && instruction.cachedCellGeneration == modules.CacheGeneration
                        && !Scheme.StrictImports)
                    {
                        cachedCell.value = value;
                        if (Value.IsLambda(value))
                        {
                            Value.AsLambda(value).name = instruction.arg1?.ToString() ?? "?";
                        }
                        break;
                    }
                    GlobalSet(instruction, value);
                    break;
                }

                case Opcode.POP:
                    stack[--sp] = null!;
                    break;

                case Opcode.CONST:
                    stack[sp++] = instruction.arg1!;
                    break;

                case Opcode.JUMP:
                    if (instruction.i1 < ip) stack = EnsureStack(stack, sp + code.Length - instruction.i1);
                    ip = instruction.i1;
                    break;

                case Opcode.FJUMP:
                    if (IsFalse(stack[--sp]))
                    {
                        if (instruction.i1 < ip) stack = EnsureStack(stack, sp + code.Length - instruction.i1);
                        ip = instruction.i1;
                    }
                    break;

                case Opcode.TJUMP:
                    if (!IsFalse(stack[--sp]))
                    {
                        if (instruction.i1 < ip) stack = EnsureStack(stack, sp + code.Length - instruction.i1);
                        ip = instruction.i1;
                    }
                    break;

                case Opcode.SAVE:
                    stack[sp++] = new ReturnAddress(instruction.i1, fn, env);
                    break;

                case Opcode.RETURN: {
                    ReturnAddress address = (ReturnAddress) stack[sp - 2];
                    fn = address.fn;
                    code = fn.codeArr;
                    env = address.env;
                    ip = address.ip;
                    stack[sp - 2] = stack[sp - 1];
                    stack[--sp] = null!;
                    stack = EnsureStack(stack, sp + code.Length - ip);
                    break;
                }

                case Opcode.GCALLJ:
                    stack[sp] = GlobalCell(instruction, instruction.arg3!, (string)instruction.arg2!).value; sp++;
                    goto case Opcode.CALLJ;

                case Opcode.CALLJ: {
                    if (thread?.terminated == true)
                        throw new SchemeError("thread terminated");
                    int argcount = instruction.i1;
                    if (argcount == -1)
                    {
                        argcount = flattened;
                        flattened = 0;
                    }
                    object f = stack[--sp];
                    if (f is Lambda lam)
                    {
                        CodeList cl = lam.cl;
                        if (cl.jit != null && !cl.builtin && depth < Jit.MaxDepth)
                        {
                            sp -= argcount;
                            object result = CallJit(lam, stack, sp, argcount, depth, -1, null, null);
                            stack = stackArr;
                            ReturnAddress address = (ReturnAddress) stack[sp - 1];
                            fn = address.fn;
                            code = fn.codeArr;
                            env = address.env;
                            ip = address.ip;
                            stack[sp - 1] = result;
                            stack = EnsureStack(stack, sp + code.Length - ip);
                            break;
                        }
                        if (cl.calls++ == Jit.Threshold) Jit.Compile(cl);
                        fn = lam;
                        code = fn.codeArr;
                        env = fn.env;
                        ip = 0;
                        nargs = argcount;
                        stack = EnsureStack(stack, sp + code.Length);
                    }
                    else if (Value.IsPrimitive(f))
                    {
                        sp -= argcount;
                        object result = ApplyPrimitive(f, instruction.pos, stack, sp, argcount);
                        ReturnAddress address = (ReturnAddress) stack[sp - 1];
                        fn = address.fn;
                        code = fn.codeArr;
                        env = address.env;
                        ip = address.ip;
                        stack[sp - 1] = result;
                        stack = EnsureStack(stack, sp + code.Length - ip);
                    }
                    else
                    {
                        throw new SchemeError(
                            instruction.pos,
                            f + " is not a function, cannot apply"
                        );
                    }
                    break;
                }

                case Opcode.GCALLS:
                    stack[sp] = GlobalCell(instruction, instruction.arg3!, (string)instruction.arg2!).value; sp++;
                    goto case Opcode.CALLS;

                case Opcode.CALLS: {
                    if (thread?.terminated == true)
                        throw new SchemeError("thread terminated");
                    int argcount = instruction.i1;
                    object f = stack[--sp];
                    if (f is Lambda lam)
                    {
                        CodeList cl = lam.cl;
                        if (cl.jit != null && !cl.builtin && depth < Jit.MaxDepth)
                        {
                            sp -= argcount;
                            object result = CallJit(lam, stack, sp, argcount, depth, ip, fn, env);
                            stack = stackArr;
                            stack[sp++] = result;
                            break;
                        }
                        if (cl.calls++ == Jit.Threshold) Jit.Compile(cl);
                        // the return address goes under the arguments,
                        // where SAVE would have put it
                        sp++;
                        int b = sp - 1 - argcount;
                        for (int i = sp - 1; i > b; i--) stack[i] = stack[i - 1];
                        stack[b] = new ReturnAddress(ip, fn, env);
                        fn = lam;
                        code = fn.codeArr;
                        env = lam.env;
                        ip = 0;
                        nargs = argcount;
                        stack = EnsureStack(stack, sp + code.Length);
                    }
                    else if (Value.IsPrimitive(f))
                    {
                        sp -= argcount;
                        stack[sp] = ApplyPrimitive(f, instruction.pos, stack, sp, argcount); sp++;
                    }
                    else
                    {
                        throw new SchemeError(
                            instruction.pos,
                            f + " is not a function, cannot apply"
                        );
                    }
                    break;
                }

                case Opcode.ARGS: {
                    if (nargs != instruction.i1)
                        throw ArityError(fn, instruction, nargs, "");
                    object[] frame = new object[nargs + 1];
                    for (int i = nargs; i >= 1; i--) { frame[i] = stack[--sp]; stack[sp] = null!; }
                    frame[0] = env;
                    env = frame;
                    break;
                }

                case Opcode.EXTEND: {
                    int n = instruction.i1;
                    object[] frame = new object[n + 1];
                    for (int i = n; i >= 1; i--) { frame[i] = stack[--sp]; stack[sp] = null!; }
                    frame[0] = env;
                    env = frame;
                    break;
                }

                case Opcode.ARGSDOT: {
                    int fixedArgs = instruction.i1;
                    if (nargs < fixedArgs)
                        throw ArityError(fn, instruction, nargs, " or more");
                    // Opt B: build object[] frame; rest list remains a Pair chain (Scheme list)
                    object rest = Value.NIL;
                    for (int i = 0; i < nargs - fixedArgs; i++)
                    {
                        rest = new Pair(stack[--sp], rest);
                        stack[sp] = null!;
                    }
                    object[] frame = new object[fixedArgs + 2];
                    frame[fixedArgs + 1] = rest;
                    for (int i = fixedArgs; i >= 1; i--) { frame[i] = stack[--sp]; stack[sp] = null!; }
                    frame[0] = env;
                    env = frame;
                    break;
                }

                case Opcode.ARGMV: {
                    // Opt B: build object[] frame
                    if (nargs == 1)
                    {
                        env = new object[] { env, stack[--sp] };
                        stack[sp] = null!;
                    }
                    else
                    {
                        object[] mv = new object[nargs];
                        for (int i = nargs - 1; i >= 0; i--) { mv[i] = stack[--sp]; stack[sp] = null!; }
                        env = new object[] { env, new Values { values = mv } };
                    }
                    break;
                }

                case Opcode.FN: {
                    Pair fn_pair = Value.AsPair(instruction.arg1!);
                    var fn_instructions = (List<Instruction>) fn_pair.Sixth();
                    var new_lambda = new Lambda(env, fn_instructions);
                    if (fn_pair.Length() > 6) new_lambda.doc = fn_pair.Eight()?.ToString();
                    stack[sp++] = new_lambda;
                    break;
                }

                case Opcode.SETCC: {
                    var k = (Continuation) stack[sp - 1];
                    if (k.act == null ? !act.root : k.act != act)
                        throw ContinuationJumpFor(k, act, fn, ip, env);
                    int b = k.act == null ? 0 : act.Base + 1;
                    sp = b + k.stack.Length;
                    stack = EnsureStack(stack, sp + code.Length - ip);
                    Array.Copy(k.stack, 0, stack, b, k.stack.Length);
                    break;
                }

                case Opcode.CC:
                    if (!act.root) throw CaptureRequest(act, fn, ip - 1, env, nargs, stack, sp);
                    stack[sp] = CaptureContinuation(stack, sp); sp++;
                    break;

                case Opcode.ECC:
                    stack[sp] = act.root ? CaptureContinuation(stack, sp) : CaptureEscape(act, stack, sp);
                    sp++;
                    break;

                case Opcode.FLATTEN_APPLY: {
                    List<object> args = FlattenApplyArgs(instruction, Getenv(env, instruction.i1, instruction.i2));
                    flattened = args.Count;
                    stack = EnsureStack(stack, sp + args.Count + code.Length - ip);
                    for (int i = 0; i < args.Count; i++)
                    {
                        stack[sp++] = args[i];
                    }
                    break;
                }

                case Opcode.FLATTEN_MULTVALS: {
                    object val = stack[--sp];
                    if (Value.IsValues(val))
                    {
                        object[] values = Value.AsValues(val).values;
                        flattened = values.Length;
                        stack = EnsureStack(stack, sp + values.Length + code.Length - ip);
                        for (int i = 0; i < values.Length; i++)
                        {
                            stack[sp++] = values[i];
                        }
                    }
                    else
                    {
                        flattened = 1;
                        stack[sp++] = val;
                    }
                    break;
                }

                case Opcode.HANDLER_RETURNED:
                    throw new SchemeError(null, new ErrorObject(
                        "raise: exception handler returned", Array.Empty<object>()));

                case Opcode.POPENV:
                    env = ((object[])env)[0];
                    break;

                case Opcode.TJUMP_KEEP:
                    if (!IsFalse(stack[sp - 1]))
                    {
                        if (instruction.i1 < ip) stack = EnsureStack(stack, sp + code.Length - instruction.i1);
                        ip = instruction.i1;
                    }
                    else
                    {
                        stack[--sp] = null!;
                    }
                    break;

                case Opcode.LOOP: {
                    if (thread?.terminated == true)
                        throw new SchemeError("thread terminated");
                    object[] parent = (object[])env;
                    for (int i = instruction.i2; i > 0; i--) parent = (object[])parent[0];
                    int n = instruction.i1;
                    object[] frame = new object[n + 1];
                    for (int i = n; i >= 1; i--) { frame[i] = stack[--sp]; stack[sp] = null!; }
                    frame[0] = parent;
                    env = frame;
                    ip = instruction.i3;
                    stack = EnsureStack(stack, sp + code.Length - ip);
                    break;
                }

                case Opcode.LVAR_CAR:
                    stack[sp] = Value.AsPair(Getenv(env, instruction.i1, instruction.i2)).car; sp++;
                    break;

                case Opcode.LVAR_CDR:
                    stack[sp] = Value.AsPair(Getenv(env, instruction.i1, instruction.i2)).cdr; sp++;
                    break;

                case Opcode.LVAR_VREF: {
                    var vec = Value.AsVector(Getenv(env, instruction.i1, instruction.i2));
                    int i = instruction.i3;
                    if (i >= vec.Length)
                        throw new SchemeError(instruction.pos, "vector-ref: index out of range: ~a", (long)i);
                    stack[sp++] = vec[i];
                    break;
                }

                case Opcode.LVAR_NULL_FJUMP:
                    if (Getenv(env, instruction.i1, instruction.i2) != Value.NIL)
                    {
                        if (instruction.i3 < ip) stack = EnsureStack(stack, sp + code.Length - instruction.i3);
                        ip = instruction.i3;
                    }
                    break;

                case Opcode.LVAR_PAIR_FJUMP:
                    if (!Value.IsPair(Getenv(env, instruction.i1, instruction.i2)))
                    {
                        if (instruction.i3 < ip) stack = EnsureStack(stack, sp + code.Length - instruction.i3);
                        ip = instruction.i3;
                    }
                    break;

                case Opcode.CONST_EQ_FJUMP:
                    if (!PrimitiveEqP.Eq(stack[--sp], instruction.arg1!))
                    {
                        if (instruction.i2 < ip) stack = EnsureStack(stack, sp + code.Length - instruction.i2);
                        ip = instruction.i2;
                    }
                    break;

                case Opcode.CAR:
                    stack[sp - 1] = Value.AsPair(stack[sp - 1]).car;
                    break;

                case Opcode.CDR:
                    stack[sp - 1] = Value.AsPair(stack[sp - 1]).cdr;
                    break;

                case Opcode.CXR: {
                    object v = stack[sp - 1];
                    for (int p = instruction.i1; p != 1; p >>= 1)
                        v = (p & 1) != 0 ? Value.AsPair(v).cdr : Value.AsPair(v).car;
                    stack[sp - 1] = v;
                    break;
                }

                case Opcode.LIST: {
                    object lst = Value.NIL;
                    for (int i = instruction.i1; i > 0; i--)
                    {
                        lst = new Pair(stack[--sp], lst);
                        stack[sp] = null!;
                    }
                    stack[sp++] = lst;
                    break;
                }

                case Opcode.CONS: {
                    object icdr = stack[--sp];
                    stack[sp - 1] = new Pair(stack[sp - 1], icdr);
                    break;
                }

                case Opcode.IS_NULL:
                    stack[sp - 1] = stack[sp - 1] == Value.NIL ? True : False;
                    break;

                case Opcode.IS_PAIR:
                    stack[sp - 1] = Value.IsPair(stack[sp - 1]) ? True : False;
                    break;

                case Opcode.NOT:
                    stack[sp - 1] = IsFalse(stack[sp - 1]) ? True : False;
                    break;

                case Opcode.LVAR_ADD_IMM: {
                    long packed = (long)instruction.arg1!;
                    object val = Getenv(env, (int)(packed >> 16), (int)(packed & 0xFFFF));
                    long imm = (long)instruction.arg2!;
                    if (val is long a)
                    {
                        long r = unchecked(a + imm);
                        if (((a ^ r) & (imm ^ r)) >= 0) { stack[sp++] = r; break; }
                    }
                    stack[sp] = Add2(val, imm); sp++;
                    break;
                }

                case Opcode.LVAR_SUB_IMM: {
                    long packed = (long)instruction.arg1!;
                    object val = Getenv(env, (int)(packed >> 16), (int)(packed & 0xFFFF));
                    long imm = (long)instruction.arg2!;
                    if (val is long a)
                    {
                        long r = unchecked(a - imm);
                        if (((a ^ imm) & (a ^ r)) >= 0) { stack[sp++] = r; break; }
                    }
                    stack[sp] = Sub2(val, imm); sp++;
                    break;
                }

                case Opcode.ADD: {
                    int n = instruction.i1;
                    if (n == 2)
                    {
                        object ib = stack[--sp], ia = stack[--sp];
                        if (ia is long a && ib is long b)
                        {
                            long r = unchecked(a + b);
                            if (((a ^ r) & (b ^ r)) >= 0) { stack[sp++] = r; break; }
                        }
                        stack[sp] = Add2(ia, ib); sp++;
                        break;
                    }
                    sp -= n;
                    stack[sp] = ApplyIntrinsic(s_primitiveAdd, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case Opcode.SUB: {
                    int n = instruction.i1;
                    if (n == 2)
                    {
                        object ib = stack[--sp], ia = stack[--sp];
                        if (ia is long a && ib is long b)
                        {
                            long r = unchecked(a - b);
                            if (((a ^ b) & (a ^ r)) >= 0) { stack[sp++] = r; break; }
                        }
                        stack[sp] = Sub2(ia, ib); sp++;
                        break;
                    }
                    if (n == 1)
                    {
                        object ia = stack[--sp];
                        stack[sp] = Negate(ia); sp++;
                        break;
                    }
                    sp -= n;
                    stack[sp] = ApplyIntrinsic(s_primitiveSub, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case Opcode.MUL: {
                    int n = instruction.i1;
                    if (n == 2)
                    {
                        object ib = stack[--sp], ia = stack[--sp];
                        if (ia is long a && ib is long b)
                        {
                            long high = Math.BigMul(a, b, out long r);
                            if ((high == 0 && r >= 0) || (high == -1 && r < 0)) { stack[sp++] = r; break; }
                        }
                        stack[sp] = Mul2(ia, ib); sp++;
                        break;
                    }
                    sp -= n;
                    stack[sp] = ApplyIntrinsic(s_primitiveMul, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case Opcode.DIV: {
                    int n = instruction.i1;
                    if (n == 2)
                    {
                        object ib = stack[--sp], ia = stack[--sp];
                        stack[sp] = Div2(instruction.pos, ia, ib); sp++;
                        break;
                    }
                    sp -= n;
                    stack[sp] = ApplyIntrinsic(s_primitiveDiv, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case Opcode.NUM_EQ: {
                    int n = instruction.i1;
                    if (n == 2)
                    {
                        object ib = stack[--sp], ia = stack[--sp];
                        bool r = ia is long a && ib is long b
                            ? a == b
                            : Compare2(Opcode.NUM_EQ, instruction.pos, ia, ib);
                        stack[sp++] = r ? True : False;
                        break;
                    }
                    sp -= n;
                    stack[sp] = ApplyIntrinsic(s_primitiveNumEq, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case Opcode.NUM_LT: {
                    int n = instruction.i1;
                    if (n == 2)
                    {
                        object ib = stack[--sp], ia = stack[--sp];
                        bool r = ia is long a && ib is long b
                            ? a < b
                            : Compare2(Opcode.NUM_LT, instruction.pos, ia, ib);
                        stack[sp++] = r ? True : False;
                        break;
                    }
                    sp -= n;
                    stack[sp] = ApplyIntrinsic(s_primitiveNumLt, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case Opcode.NUM_GT: {
                    int n = instruction.i1;
                    if (n == 2)
                    {
                        object ib = stack[--sp], ia = stack[--sp];
                        bool r = ia is long a && ib is long b
                            ? a > b
                            : Compare2(Opcode.NUM_GT, instruction.pos, ia, ib);
                        stack[sp++] = r ? True : False;
                        break;
                    }
                    sp -= n;
                    stack[sp] = ApplyIntrinsic(s_primitiveNumGt, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case Opcode.NUM_LTE: {
                    int n = instruction.i1;
                    if (n == 2)
                    {
                        object ib = stack[--sp], ia = stack[--sp];
                        bool r = ia is long a && ib is long b
                            ? a <= b
                            : Compare2(Opcode.NUM_LTE, instruction.pos, ia, ib);
                        stack[sp++] = r ? True : False;
                        break;
                    }
                    sp -= n;
                    stack[sp] = ApplyIntrinsic(s_primitiveNumLte, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case Opcode.NUM_GTE: {
                    int n = instruction.i1;
                    if (n == 2)
                    {
                        object ib = stack[--sp], ia = stack[--sp];
                        bool r = ia is long a && ib is long b
                            ? a >= b
                            : Compare2(Opcode.NUM_GTE, instruction.pos, ia, ib);
                        stack[sp++] = r ? True : False;
                        break;
                    }
                    sp -= n;
                    stack[sp] = ApplyIntrinsic(s_primitiveNumGte, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case Opcode.EQ_P: {
                    object ib = stack[--sp], ia = stack[--sp];
                    stack[sp++] = PrimitiveEqP.Eq(ia, ib) ? True : False;
                    break;
                }

                case Opcode.EQV_P: {
                    object ib = stack[--sp], ia = stack[--sp];
                    stack[sp++] = PrimitiveEqvP.Eqv(ia, ib) ? True : False;
                    break;
                }

                case Opcode.VECTOR_REF: {
                    object idx = stack[--sp];
                    var vec = Value.AsVector(stack[--sp]);
                    int i = IntegerMath.ToInt(idx);
                    if (i < 0 || i >= vec.Length)
                        throw new SchemeError(instruction.pos, "vector-ref: index out of range: ~a", idx);
                    stack[sp++] = vec[i];
                    break;
                }

                case Opcode.VECTOR_SET: {
                    object val = stack[--sp];
                    object idx = stack[--sp];
                    var vec = Value.AsVector(stack[--sp]);
                    int i = IntegerMath.ToInt(idx);
                    if (i < 0 || i >= vec.Length)
                        throw new SchemeError(instruction.pos, "vector-set!: index out of range: ~a", idx);
                    vec[i] = val;
                    stack[sp++] = new Values();
                    break;
                }

                default:
                    throw new SchemeError(
                        instruction.pos,
                        "Unknown opcode " + instruction.opcode
                    );
            }
        }
        break;
        } // end try
        catch (SchemeError e)
        {
            pending = e;
        }
        catch (InvalidCastException e)
        {
            pending = CastError(fn, ip, e);
        }
        catch (FrameCapture fc)
        {
            if (!act.root)
            {
                if (fc.last != act) fc.Add(stackArr[(act.Base + 1)..sp], act);
                Leave(act, sp);
                throw;
            }
            // rebuild the unwound frames on the root's stack
            stack = stackArr;
            for (int s = fc.segments.Count - 1; s >= 0; s--)
            {
                object[] seg = fc.segments[s];
                Activation? owner = fc.owners[s];
                if (owner != null) PromoteEscapes(owner, stack, sp);
                stack = EnsureStack(stack, sp + seg.Length);
                Array.Copy(seg, 0, stack, sp, seg.Length);
                sp += seg.Length;
            }
            fn = fc.fn; code = fn.codeArr; ip = fc.ip; env = fc.env; nargs = fc.nargs;
            stack = EnsureStack(stack, sp + code.Length - ip);
            if (fc.cause == FrameCapture.CAPTURE) continue;
            pending = fc.cause is InvalidCastException ice ? CastError(fn, ip, ice) : (Exception)fc.cause;
        }
        catch (ContinuationJump j)
        {
            if (j.target != act)
            {
                Leave(act, sp);
                throw;
            }
            Continuation k = j.continuation;
            int b = k.act == null ? 0 : act.Base + 1;
            sp = b + k.stack.Length;
            stack = EnsureStack(stackArr, sp);
            Array.Copy(k.stack, 0, stack, b, k.stack.Length);
            fn = j.fn; code = fn.codeArr; ip = j.ip; env = j.env;
            stack = EnsureStack(stack, sp + code.Length - ip);
            continue;
        }
        // an error at fn/ip: the innermost exception handler is called on
        // top of the stack; with none, it leaves the root (with every
        // frame in its call stack: a nested activation unwinds to the root)
        SchemeError e2 = pending as SchemeError
            ?? new SchemeError((SourcePos?)null, "internal error: " + pending);
        this.fn = fn; this.ip = ip; this.env = env; this.sp = sp;
        if (exceptionHandlers != Value.NIL)
        {
            if (e2.schemeCallStack == null)
                e2.schemeCallStack = ExtractCallStack();
            object condition = (object?)e2.errorObject ?? new ErrorObject(e2.Message, Array.Empty<object>());
            this.nargs = nargs;
            SetupRaiseCall(condition);
            fn = this.fn!; code = fn.codeArr; ip = this.ip; env = this.env;
            sp = this.sp; nargs = this.nargs;
            stack = EnsureStack(stackArr, sp + code.Length - ip);
            continue;
        }
        if (!act.root)
        {
            if (Jit.Stats) Jit.statErrors++;
            var fc = new FrameCapture(e2, fn, ip, env, nargs);
            fc.Add(stackArr[(act.Base + 1)..sp], act);
            Leave(act, sp);
            throw fc;
        }
        if (e2.schemeCallStack == null)
            e2.schemeCallStack = ExtractCallStack();
        this.sp = act.Base;
        winders = savedWinders!;
        exceptionHandlers = savedExceptionHandlers!;
        if (e2 == pending) System.Runtime.ExceptionServices.ExceptionDispatchInfo.Capture(e2).Throw();
        throw e2;
        }
        if (act.root) { this.fn = fn; this.ip = ip; this.env = env; }
        object returnValue = stack[--sp];
        stack[sp] = null!;
        this.sp = sp;
        return returnValue;
    }

    // Clears the stack of activation a, left by an exception.
    private void Leave(Activation a, int sp)
    {
        if (sp > a.Base) Array.Clear(stackArr, a.Base, Math.Min(sp, stackArr.Length) - a.Base);
        this.sp = a.Base;
    }

    private void CountCall(string s)
    {
        if (call_counts.ContainsKey(s))
        {
            call_counts[s] += 1;
        }
        else
        {
            call_counts[s] = 1;
        }
    }
}
