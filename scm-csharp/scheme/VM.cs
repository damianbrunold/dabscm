using System.Numerics;

namespace scheme;

public class VM
{
    private Modules modules;

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

    private readonly Lambda raiseReturnedLambda;

    // Static primitive instances for intrinsic fallbacks (variable-arity / edge-case paths)
    private static readonly PrimitiveAdd s_primitiveAdd = new();
    private static readonly PrimitiveSub s_primitiveSub = new();
    private static readonly PrimitiveMul s_primitiveMul = new();
    private static readonly PrimitiveDiv s_primitiveDiv = new();
    private static readonly PrimitiveNumequal s_primitiveNumEq = new();
    private static readonly PrimitiveNumless s_primitiveNumLt = new();
    private static readonly PrimitiveNumgreater s_primitiveNumGt = new();
    private static readonly PrimitiveNumlessequal s_primitiveNumLte = new();
    private static readonly PrimitiveNumgreaterequal s_primitiveNumGte = new();

    // The Scheme name of an opcode that can fail with a wrong argument type,
    // for the error message; null for the VM's internal opcodes.
    private static string? OpcodeErrorName(Opcode op) => op switch
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
    private static SchemeError WrongArgumentTypeError(SourcePos? pos, string name, InvalidCastException e)
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
    private static readonly object True = Value.T;
    private static readonly object False = Value.F;

    private static bool IsFalse(object value) => value is bool b && !b;

    private static object PrimaryValue(object value)
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
        SourcePos? currentPos = (fn != null && ip > 0 && ip - 1 < fn.code.Count)
            ? fn.code[ip - 1].pos : null;
        frames.Add(new SchemeCallFrame(fn?.name, currentPos));
        for (int i = sp - 1; i >= 0; i--)
            if (stackArr[i] is ReturnAddress addr)
            {
                SourcePos? callPos = (addr.ip > 0 && addr.ip - 1 < addr.fn.code.Count)
                    ? addr.fn.code[addr.ip - 1].pos : null;
                frames.Add(new SchemeCallFrame(addr.fn.name, callPos));
            }
        return frames;
    }

    // Cold paths of the dispatch loop, kept out of Execute so that the JIT
    // compiles the loop itself well.

    // The binding cell of a global variable, cached in the instruction
    // (GVAR, GCALLS, GCALLJ).
    private Cell GlobalCell(Instruction instruction, object symbolObj, string moduleName)
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

    private void GlobalSet(Instruction instruction, object value)
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

    private static SchemeError ArityError(Lambda fn, Instruction instruction, int nargs, string expected)
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
    private static object Add2(object ia, object ib)
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

    private static object Sub2(object ia, object ib)
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

    private static object Mul2(object ia, object ib)
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

    private static object Div2(SourcePos? pos, object ia, object ib)
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

    private static object Negate(object ia)
    {
        if (ia is long ial) return IntegerMath.Negate(ial);
        if (Value.IsBigInteger(ia)) return IntegerMath.GenericNegate(ia);
        if (ia is double iad) return -iad;
        if (ia is Complex) return Complex.Negate(ia);
        return Rational.Sub(0L, ia);
    }

    // =, <, >, <=, >= on two numbers that are not both fixnums.
    private static bool Compare2(Opcode op, SourcePos? pos, object ia, object ib)
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
    private static List<object> FlattenApplyArgs(Instruction instruction, object restObj)
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

    // The value stack of a continuation, restored by SETCC. Sharing the
    // ReturnAddress entries is safe: they are never modified.
    private sealed class Continuation
    {
        public readonly object[] stack;

        public Continuation(object[] stack, int sp)
        {
            this.stack = stack[..sp];
        }
    }

    // The continuation of the current stack as a procedure (CC).
    private static Lambda CaptureContinuation(object[] stack, int sp)
    {
        var capturedStack = new Continuation(stack, sp);
        List<Instruction> newcode = new();
        newcode.Add(new Instruction(Opcode.ARGMV));
        newcode.Add(new Instruction(Opcode.LVAR, 1, 0));
        newcode.Add(new Instruction(Opcode.SETCC));
        newcode.Add(new Instruction(Opcode.LVAR, 0, 0));
        newcode.Add(new Instruction(Opcode.RETURN));
        // Opt B: env frame must be object[]
        object capturedEnv = new object[] { Value.NIL, capturedStack };
        return new Lambda(capturedEnv, newcode);
    }

    public object Execute(Lambda func)
    {
        VM? savedCurrent = VM.Current;
        VM.Current = this;
        try
        {
        if (SchemeThread.CurrentThread == null)
        {
            var primordial = new SchemeThread(null, modules);
            primordial.name = Value.Intern("primordial");
            primordial.state = SchemeThreadState.STARTED;
            SchemeThread.CurrentThread = primordial;
        }
        SchemeThread? currentThread = SchemeThread.CurrentThread;
        int savedSp = this.sp;
        object savedWinders = winders;
        object savedExceptionHandlers = exceptionHandlers;
        Push(new ReturnAddress(func.code.Count, func, this.env));
        Lambda fn = func;
        Instruction[] code = fn.codeArr;
        int ip = 0;
        object env = this.env;
        int sp = this.sp;
        object[] stack = EnsureStack(stackArr, sp + code.Length);
        int nargs = 0;
        continueExecution:
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
                    if (currentThread?.terminated == true)
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
                        //CountCall(Value.DisplayRep(f));
                        fn = lam;
                        code = fn.codeArr;
                        env = fn.env;
                        ip = 0;
                        nargs = argcount;
                        stack = EnsureStack(stack, sp + code.Length);
                    }
                    else if (Value.IsPrimitive(f))
                    {
                        //CountCall(Value.DisplayRep(f));
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
                    if (currentThread?.terminated == true)
                        throw new SchemeError("thread terminated");
                    int argcount = instruction.i1;
                    object f = stack[--sp];
                    if (f is Lambda lam)
                    {
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
                    sp = k.stack.Length;
                    stack = EnsureStack(stack, sp + code.Length - ip);
                    Array.Copy(k.stack, stack, sp);
                    break;
                }

                case Opcode.CC:
                    stack[sp] = CaptureContinuation(stack, sp); sp++;
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
                    if (currentThread?.terminated == true)
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
        } // end try
        catch (SchemeError e)
        {
            this.fn = fn; this.ip = ip; this.env = env; this.sp = sp;
            if (e.schemeCallStack == null)
                e.schemeCallStack = ExtractCallStack();
            if (exceptionHandlers != Value.NIL)
            {
                object condition = (object?)e.errorObject ?? new ErrorObject(e.Message, Array.Empty<object>());
                this.nargs = nargs;
                SetupRaiseCall(condition);
                fn = this.fn!; code = fn.codeArr; ip = this.ip; env = this.env;
                sp = this.sp; nargs = this.nargs;
                stack = EnsureStack(stackArr, sp + code.Length - ip);
                goto continueExecution;
            }
            this.sp = savedSp;
            winders = savedWinders;
            exceptionHandlers = savedExceptionHandlers;
            throw;
        }
        catch (InvalidCastException e)
        {
            // No opcode changes ip or fn before it can fail a cast, so the
            // failing instruction is the one fetched last.
            Instruction? failed = ip > 0 && ip <= fn.code.Count ? fn.code[ip - 1] : null;
            string name = failed == null ? "VM"
                : failed.opcode == Opcode.CXR ? (string)failed.arg2!
                : OpcodeErrorName(failed.opcode) ?? failed.opcode + " instruction";
            var err = WrongArgumentTypeError(failed?.pos, name, e);
            this.fn = fn; this.ip = ip; this.env = env; this.sp = sp;
            err.schemeCallStack = ExtractCallStack();
            if (exceptionHandlers != Value.NIL)
            {
                this.nargs = nargs;
                SetupRaiseCall(err.errorObject!);
                fn = this.fn!; code = fn.codeArr; ip = this.ip; env = this.env;
                sp = this.sp; nargs = this.nargs;
                stack = EnsureStack(stackArr, sp + code.Length - ip);
                goto continueExecution;
            }
            this.sp = savedSp;
            winders = savedWinders;
            exceptionHandlers = savedExceptionHandlers;
            throw err;
        }
        this.fn = fn; this.ip = ip; this.env = env;
        object returnValue = stack[--sp];
        stack[sp] = null!;
        this.sp = sp;
        return returnValue;
        }
        finally
        {
            VM.Current = savedCurrent;
        }
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
