using System.Numerics;

namespace scheme;

public class VM
{
    private Modules modules;
    private Lambda? fn;
    private int ip;
    private object env = Value.NIL;

    // Opt A: array-based stack (eliminates one Pair allocation per Push)
    private object[] stackArr = new object[512];
    private int sp = 0;

    private int nargs = 0;
    private int flattened = 0;
    private string? _intrinsicName;   // set before each intrinsic for error messages
    private SourcePos? _intrinsicPos;

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

    private static object Elt(object list, int n)
    {
        for (int i = 0; i < n; i++)
        {
            list = Value.AsPair(list).cdr;
        }
        return Value.AsPair(list).car;
    }

    // Opt B: frames are now object[] instead of Pair chains — O(1) variable access
    private object Getenv(int frame, int variable)
    {
        if (frame == 0) return ((object[])Value.AsPair(env).car)[variable];
        return ((object[])Elt(env, frame))[variable];
    }

    private void Setenv(int frame, int variable, object value)
        => ((object[])Elt(env, frame))[variable] = value;

    // Opt A: array-based stack operations
    private void Push(object value)
    {
        if (sp == stackArr.Length)
        {
            var bigger = new object[stackArr.Length * 2];
            Array.Copy(stackArr, bigger, sp);
            stackArr = bigger;
        }
        stackArr[sp++] = value;
    }

    private object Pop()
    {
        object value = stackArr[--sp];
        stackArr[sp] = null!; // clear for GC
        return value;
    }

    private object Top() => stackArr[sp - 1];
    private object Second() => stackArr[sp - 2];

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
        int savedSp = sp;
        object savedWinders = winders;
        object savedExceptionHandlers = exceptionHandlers;
        Push(new ReturnAddress(func.code.Count, func, env));
        this.fn = func;
        this.ip = 0;
        this.nargs = 0;
        continueExecution:
        try
        {
        while (ip < this.fn.code.Count)
        {
            Instruction instruction = this.fn.code[ip++];
            switch (instruction.opcode)
            {
                case Opcode.LVAR:
                    Push(Getenv((int) instruction.arg1!,
                                (int) instruction.arg2!));
                    break;

                case Opcode.LSET:
                    Setenv(
                        (int) instruction.arg1!,
                        (int) instruction.arg2!,
                        PrimaryValue(Top())
                    );
                    break;

                case Opcode.GVAR:
                    try
                    {
                        var moduleName = (string)instruction.arg2!;
                        Push(modules.GetModuleRequired(instruction.pos, moduleName).Resolve(instruction.pos, Value.AsSymbol(instruction.arg1!)));
                    }
                    catch (SchemeError)
                    {
                        throw;
                    }
                    catch (Exception)
                    {
                        throw new SchemeError(
                            instruction.pos,
                            "internal error"
                        );
                    }
                    break;

                case Opcode.GSET: {
                    object value = PrimaryValue(Top());
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
                    if (Value.IsLambda(value))
                    {
                        Value.AsLambda(value).name = instruction.arg1?.ToString() ?? "?";
                    }
                    break;
                }

                case Opcode.POP:
                    Pop();
                    break;

                case Opcode.CONST:
                    Push(instruction.arg1!);
                    break;

                case Opcode.JUMP:
                    ip = (int) instruction.arg1!;
                    break;

                case Opcode.FJUMP:
                    if (Pop().Equals(Value.F)) ip = (int) instruction.arg1!;
                    break;

                case Opcode.TJUMP:
                    if (!Pop().Equals(Value.F)) ip = (int) instruction.arg1!;
                    break;

                case Opcode.SAVE:
                    Push(new ReturnAddress((int) instruction.arg1!, this.fn, env));
                    break;

                case Opcode.RETURN: {
                    ReturnAddress address = (ReturnAddress) Second();
                    this.fn = address.fn;
                    env = address.env;
                    ip = address.ip;
                    object value = Pop();
                    Pop();
                    Push(value);
                    break;
                }

                case Opcode.CALLJ: {
                    if (SchemeThread.CurrentThread?.terminated == true)
                        throw new SchemeError("thread terminated");
                    int argcount = (int) instruction.arg1!;
                    if (argcount == -1)
                    {
                        argcount = flattened;
                        flattened = 0;
                    }
                    env = Value.AsPair(env).cdr; // discard top frame
                    object f = Pop();
                    if (Value.IsLambda(f))
                    {
                        //CountCall(Value.DisplayRep(f));
                        this.fn = Value.AsLambda(f);
                        env = fn.env;
                        ip = 0;
                        nargs = argcount;
                    }
                    else if (Value.IsPrimitive(f))
                    {
                        //CountCall(Value.DisplayRep(f));
                        // Opt C: use pooled arg arrays
                        object[] args = RentArgs(argcount);
                        nargs = args.Length;
                        for (int i = args.Length - 1; i >= 0; i--) args[i] = PrimaryValue(Pop());
                        object result;
                        try
                        {
                            result = Value.AsPrimitive(f).Apply(instruction.pos, args);
                        }
                        catch (SchemeError)
                        {
                            ReturnArgs(args);
                            throw;
                        }
                        catch (InvalidCastException)
                        {
                            ReturnArgs(args);
                            throw new SchemeError(instruction.pos, "Failed in " + Value.AsPrimitive(f).Name() + ": wrong argument type");
                        }
                        catch (Exception e)
                        {
                            ReturnArgs(args);
                            throw new SchemeError(instruction.pos, "Failed in " + Value.AsPrimitive(f).Name() +": " + e.Message);
                        }
                        // If a primitive stored the args array directly in the result (e.g. `values`),
                        // clone it before clearing so the result isn't corrupted.
                        if (result is Values pooledVals && object.ReferenceEquals(pooledVals.values, args))
                            pooledVals.values = (object[])args.Clone();
                        ReturnArgs(args);
                        Push(result);
                        ReturnAddress address = (ReturnAddress) Second();
                        this.fn = address.fn;
                        env = address.env;
                        ip = address.ip;
                        object val = Pop();
                        Pop();
                        Push(val);
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
                    if (nargs != (int) instruction.arg1!)
                    {
                        throw new SchemeError(
                            instruction.pos,
                            (fn.name != null ? fn.name + " " : "") +
                            "Wrong number of arguments: "
                            + instruction.arg1! + " expected, "
                            + nargs + " supplied"
                        );
                    }
                    // Opt B: build object[] frame instead of Pair chain
                    object[] frame = new object[nargs];
                    for (int i = nargs - 1; i >= 0; i--) frame[i] = Pop();
                    env = new Pair(frame, env);
                    break;
                }

                case Opcode.EXTEND: {
                    int n = (int) instruction.arg1!;
                    object[] frame = new object[n];
                    for (int i = n - 1; i >= 0; i--) frame[i] = Pop();
                    env = new Pair(frame, env);
                    break;
                }

                case Opcode.ARGSDOT: {
                    int fixedArgs = (int) instruction.arg1!;
                    if (nargs < fixedArgs)
                    {
                        throw new SchemeError(
                            instruction.pos,
                            (fn.name != null ? fn.name + " " : "") +
                            "Wrong number of arguments: "
                            + instruction.arg1 + " or more expected, "
                            + nargs + " supplied"
                        );
                    }
                    // Opt B: build object[] frame; rest list remains a Pair chain (Scheme list)
                    object rest = Value.NIL;
                    for (int i = 0; i < nargs - fixedArgs; i++)
                        rest = new Pair(Pop(), rest);
                    object[] frame = new object[fixedArgs + 1];
                    frame[fixedArgs] = rest;
                    for (int i = fixedArgs - 1; i >= 0; i--) frame[i] = Pop();
                    env = new Pair(frame, env);
                    break;
                }

                case Opcode.ARGMV: {
                    // Opt B: build object[] frame
                    if (nargs == 1)
                    {
                        env = new Pair(new object[] { Pop() }, env);
                    }
                    else
                    {
                        object[] mv = new object[nargs];
                        for (int i = nargs - 1; i >= 0; i--) mv[i] = Pop();
                        env = new Pair(new object[] { new Values { values = mv } }, env);
                    }
                    break;
                }

                case Opcode.FN: {
                    Pair fn_pair = Value.AsPair(instruction.arg1!);
                    var fn_instructions = (List<Instruction>) fn_pair.Sixth();
                    var new_lambda = new Lambda(env, fn_instructions);
                    if (fn_pair.Length() > 6) new_lambda.doc = fn_pair.Eight()?.ToString();
                    Push(new_lambda);
                    break;
                }

                case Opcode.SETCC: {
                    // Opt A: restore array stack from captured Pair chain
                    object savedStack = Top();
                    sp = 0;
                    for (object p = savedStack; p != Value.NIL; p = Value.AsPair(p).cdr)
                        Push(Value.AsPair(p).car);
                    break;
                }

                case Opcode.CC: {
                    // Opt A: serialize array stack to Pair chain for capture
                    object capturedStack = Value.NIL;
                    for (int i = sp - 1; i >= 0; i--)
                        capturedStack = new Pair(stackArr[i], capturedStack);
                    List<Instruction> newcode = new();
                    newcode.Add(new Instruction(Opcode.ARGMV));
                    newcode.Add(new Instruction(Opcode.LVAR, 1, 0));
                    newcode.Add(new Instruction(Opcode.SETCC));
                    newcode.Add(new Instruction(Opcode.LVAR, 0, 0));
                    newcode.Add(new Instruction(Opcode.RETURN));
                    // Opt B: env frame must be object[]
                    Pair capturedEnv = new Pair(new object[] { capturedStack }, Value.NIL);
                    Push(new Lambda(capturedEnv, newcode));
                    break;
                }

                case Opcode.FLATTEN_APPLY: {
                    List<object> args = new();
                    object restObj = Getenv((int)instruction.arg1!, (int)instruction.arg2!);
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
                    flattened = args.Count;
                    for (int i = 0; i < args.Count; i++)
                    {
                        Push(args[i]);
                    }
                    break;
                }

                case Opcode.FLATTEN_MULTVALS: {
                    object val = Pop();
                    if (Value.IsValues(val))
                    {
                        object[] values = Value.AsValues(val).values;
                        flattened = values.Length;
                        for (int i = 0; i < values.Length; i++)
                        {
                            Push(values[i]);
                        }
                    }
                    else
                    {
                        flattened = 1;
                        Push(val);
                    }
                    break;
                }

                case Opcode.HANDLER_RETURNED:
                    throw new SchemeError(null, new ErrorObject(
                        "raise: exception handler returned", Array.Empty<object>()));

                case Opcode.CAR:
                    _intrinsicName = "car"; _intrinsicPos = instruction.pos;
                    Push(Value.AsPair(Pop()).car);
                    break;

                case Opcode.CDR:
                    _intrinsicName = "cdr"; _intrinsicPos = instruction.pos;
                    Push(Value.AsPair(Pop()).cdr);
                    break;

                case Opcode.CONS: {
                    _intrinsicName = "cons"; _intrinsicPos = instruction.pos;
                    object icdr = Pop(), icar = Pop();
                    Push(new Pair(icar, icdr));
                    break;
                }

                case Opcode.IS_NULL:
                    _intrinsicName = "null?"; _intrinsicPos = instruction.pos;
                    Push(Pop() == Value.NIL ? Value.T : Value.F);
                    break;

                case Opcode.IS_PAIR: {
                    _intrinsicName = "pair?"; _intrinsicPos = instruction.pos;
                    object ipv = Pop();
                    Push(Value.IsPair(ipv) ? Value.T : Value.F);
                    break;
                }

                case Opcode.NOT:
                    _intrinsicName = "not"; _intrinsicPos = instruction.pos;
                    Push(Pop().Equals(Value.F) ? Value.T : Value.F);
                    break;

                case Opcode.LVAR_ADD_IMM: {
                    long packed = (long)instruction.arg1!;
                    object val = Getenv((int)(packed >> 16), (int)(packed & 0xFFFF));
                    long imm = (long)instruction.arg2!;
                    if (val is long lv) {
                        try { checked { Push(lv + imm); } }
                        catch (OverflowException) { Push((BigInteger)lv + imm); }
                        break;
                    }
                    if (Value.IsBigInteger(val)) { Push(IntegerMath.GenericAdd(val, imm)); break; }
                    if (val is double dv) { Push(dv + (double)imm); break; }
                    if (val is Complex) { Push(Complex.Add(val, imm)); break; }
                    Push(Rational.Add(val, imm)); break;
                }

                case Opcode.LVAR_SUB_IMM: {
                    long packed = (long)instruction.arg1!;
                    object val = Getenv((int)(packed >> 16), (int)(packed & 0xFFFF));
                    long imm = (long)instruction.arg2!;
                    if (val is long lv) {
                        try { checked { Push(lv - imm); } }
                        catch (OverflowException) { Push((BigInteger)lv - imm); }
                        break;
                    }
                    if (Value.IsBigInteger(val)) { Push(IntegerMath.GenericSub(val, imm)); break; }
                    if (val is double dv) { Push(dv - (double)imm); break; }
                    if (val is Complex) { Push(Complex.Sub(val, imm)); break; }
                    Push(Rational.Sub(val, imm)); break;
                }

                case Opcode.ADD: {
                    _intrinsicName = "+"; _intrinsicPos = instruction.pos;
                    int n = (int)instruction.arg1!;
                    if (n == 0) { Push(0L); break; }
                    if (n == 2) {
                        object ib = Pop(), ia = Pop();
                        if (ia is long ial && ib is long ibl) {
                            try { checked { Push(ial + ibl); } }
                            catch (OverflowException) { Push((BigInteger)ial + ibl); }
                            break;
                        }
                        if (Value.IsInteger(ia) && Value.IsInteger(ib)) { Push(IntegerMath.GenericAdd(ia, ib)); break; }
                        if (ia is double || ib is double) {
                            if (ia is Complex || ib is Complex) { Push(Complex.Add(ia, ib)); break; }
                            Push(VmToReal(ia) + VmToReal(ib)); break;
                        }
                        if (ia is Complex || ib is Complex) { Push(Complex.Add(ia, ib)); break; }
                        Push(Rational.Add(ia, ib)); break;
                    }
                    object[] iarr = RentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = Pop();
                    Push(s_primitiveAdd.Apply(instruction.pos, iarr));
                    ReturnArgs(iarr);
                    break;
                }

                case Opcode.SUB: {
                    _intrinsicName = "-"; _intrinsicPos = instruction.pos;
                    int n = (int)instruction.arg1!;
                    if (n == 1) {
                        object ia = Pop();
                        if (ia is long ial) { Push(IntegerMath.Negate(ial)); break; }
                        if (Value.IsBigInteger(ia)) { Push(IntegerMath.GenericNegate(ia)); break; }
                        if (ia is double iad) { Push(-iad); break; }
                        if (ia is Complex) { Push(Complex.Negate(ia)); break; }
                        Push(Rational.Sub(0L, ia)); break;
                    }
                    if (n == 2) {
                        object ib = Pop(), ia = Pop();
                        if (ia is long ial && ib is long ibl) {
                            try { checked { Push(ial - ibl); } }
                            catch (OverflowException) { Push((BigInteger)ial - ibl); }
                            break;
                        }
                        if (Value.IsInteger(ia) && Value.IsInteger(ib)) { Push(IntegerMath.GenericSub(ia, ib)); break; }
                        if (ia is double || ib is double) {
                            if (ia is Complex || ib is Complex) { Push(Complex.Sub(ia, ib)); break; }
                            Push(VmToReal(ia) - VmToReal(ib)); break;
                        }
                        if (ia is Complex || ib is Complex) { Push(Complex.Sub(ia, ib)); break; }
                        Push(Rational.Sub(ia, ib)); break;
                    }
                    object[] iarr = RentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = Pop();
                    Push(s_primitiveSub.Apply(instruction.pos, iarr));
                    ReturnArgs(iarr);
                    break;
                }

                case Opcode.MUL: {
                    _intrinsicName = "*"; _intrinsicPos = instruction.pos;
                    int n = (int)instruction.arg1!;
                    if (n == 0) { Push(1L); break; }
                    if (n == 2) {
                        object ib = Pop(), ia = Pop();
                        if (ia is long ial && ib is long ibl) {
                            try { checked { Push(ial * ibl); } }
                            catch (OverflowException) { Push((BigInteger)ial * ibl); }
                            break;
                        }
                        if (Value.IsInteger(ia) && Value.IsInteger(ib)) { Push(IntegerMath.GenericMul(ia, ib)); break; }
                        if (ia is double || ib is double) {
                            if (ia is Complex || ib is Complex) { Push(Complex.Mul(ia, ib)); break; }
                            Push(VmToReal(ia) * VmToReal(ib)); break;
                        }
                        if (ia is Complex || ib is Complex) { Push(Complex.Mul(ia, ib)); break; }
                        Push(Rational.Mul(ia, ib)); break;
                    }
                    object[] iarr = RentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = Pop();
                    Push(s_primitiveMul.Apply(instruction.pos, iarr));
                    ReturnArgs(iarr);
                    break;
                }

                case Opcode.DIV: {
                    _intrinsicName = "/"; _intrinsicPos = instruction.pos;
                    int n = (int)instruction.arg1!;
                    if (n == 2) {
                        object ib = Pop(), ia = Pop();
                        if (ia is long ial && ib is long ibl) {
                            if (ibl == 0) throw new SchemeError(instruction.pos, "/: Division by zero");
                            Push(Rational.Div(ial, ibl)); break;
                        }
                        if (ia is double || ib is double) {
                            if (ia is Complex || ib is Complex) { Push(Complex.Div(ia, ib)); break; }
                            double dib = VmToReal(ib);
                            if (dib == 0.0) throw new SchemeError(instruction.pos, "/: Division by ~s", dib);
                            Push(VmToReal(ia) / dib); break;
                        }
                        if (ia is Complex || ib is Complex) { Push(Complex.Div(ia, ib)); break; }
                        Push(Rational.Div(ia, ib)); break;
                    }
                    object[] iarr = RentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = Pop();
                    Push(s_primitiveDiv.Apply(instruction.pos, iarr));
                    ReturnArgs(iarr);
                    break;
                }

                case Opcode.NUM_EQ: {
                    _intrinsicName = "="; _intrinsicPos = instruction.pos;
                    int n = (int)instruction.arg1!;
                    if (n == 2) {
                        object ib = Pop(), ia = Pop();
                        if (ia is long ial && ib is long ibl) { Push(ial == ibl ? Value.T : Value.F); break; }
                        if (Value.IsInteger(ia) && Value.IsInteger(ib)) { Push(IntegerMath.GenericEquals(ia, ib) ? Value.T : Value.F); break; }
                        if (ia is double iad && ib is double ibd) { Push(iad == ibd ? Value.T : Value.F); break; }
                        if (ia is Complex || ib is Complex) { Push(Complex.NumericEquals(ia, ib) ? Value.T : Value.F); break; }
                        Push(Primitive.MixedNumericEquals(ia, ib) ? Value.T : Value.F); break;
                    }
                    object[] iarr = RentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = Pop();
                    Push(s_primitiveNumEq.Apply(instruction.pos, iarr));
                    ReturnArgs(iarr);
                    break;
                }

                case Opcode.NUM_LT: {
                    _intrinsicName = "<"; _intrinsicPos = instruction.pos;
                    int n = (int)instruction.arg1!;
                    if (n == 2) {
                        object ib = Pop(), ia = Pop();
                        if (ia is long ial && ib is long ibl) { Push(ial < ibl ? Value.T : Value.F); break; }
                        if (Value.IsInteger(ia) && Value.IsInteger(ib)) { Push(IntegerMath.Compare(ia, ib) < 0 ? Value.T : Value.F); break; }
                        if (ia is Complex || ib is Complex) throw new SchemeError(instruction.pos, "<: complex numbers are not ordered");
                        Push(Primitive.MixedNumericCompare(ia, ib) < 0 ? Value.T : Value.F); break;
                    }
                    object[] iarr = RentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = Pop();
                    Push(s_primitiveNumLt.Apply(instruction.pos, iarr));
                    ReturnArgs(iarr);
                    break;
                }

                case Opcode.NUM_GT: {
                    _intrinsicName = ">"; _intrinsicPos = instruction.pos;
                    int n = (int)instruction.arg1!;
                    if (n == 2) {
                        object ib = Pop(), ia = Pop();
                        if (ia is long ial && ib is long ibl) { Push(ial > ibl ? Value.T : Value.F); break; }
                        if (Value.IsInteger(ia) && Value.IsInteger(ib)) { Push(IntegerMath.Compare(ia, ib) > 0 ? Value.T : Value.F); break; }
                        if (ia is Complex || ib is Complex) throw new SchemeError(instruction.pos, ">: complex numbers are not ordered");
                        Push(Primitive.MixedNumericCompare(ia, ib) > 0 ? Value.T : Value.F); break;
                    }
                    object[] iarr = RentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = Pop();
                    Push(s_primitiveNumGt.Apply(instruction.pos, iarr));
                    ReturnArgs(iarr);
                    break;
                }

                case Opcode.NUM_LTE: {
                    _intrinsicName = "<="; _intrinsicPos = instruction.pos;
                    int n = (int)instruction.arg1!;
                    if (n == 2) {
                        object ib = Pop(), ia = Pop();
                        if (ia is long ial && ib is long ibl) { Push(ial <= ibl ? Value.T : Value.F); break; }
                        if (Value.IsInteger(ia) && Value.IsInteger(ib)) { Push(IntegerMath.Compare(ia, ib) <= 0 ? Value.T : Value.F); break; }
                        if (ia is Complex || ib is Complex) throw new SchemeError(instruction.pos, "<=: complex numbers are not ordered");
                        Push(Primitive.MixedNumericCompare(ia, ib) <= 0 ? Value.T : Value.F); break;
                    }
                    object[] iarr = RentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = Pop();
                    Push(s_primitiveNumLte.Apply(instruction.pos, iarr));
                    ReturnArgs(iarr);
                    break;
                }

                case Opcode.NUM_GTE: {
                    _intrinsicName = ">="; _intrinsicPos = instruction.pos;
                    int n = (int)instruction.arg1!;
                    if (n == 2) {
                        object ib = Pop(), ia = Pop();
                        if (ia is long ial && ib is long ibl) { Push(ial >= ibl ? Value.T : Value.F); break; }
                        if (Value.IsInteger(ia) && Value.IsInteger(ib)) { Push(IntegerMath.Compare(ia, ib) >= 0 ? Value.T : Value.F); break; }
                        if (ia is Complex || ib is Complex) throw new SchemeError(instruction.pos, ">=: complex numbers are not ordered");
                        Push(Primitive.MixedNumericCompare(ia, ib) >= 0 ? Value.T : Value.F); break;
                    }
                    object[] iarr = RentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = Pop();
                    Push(s_primitiveNumGte.Apply(instruction.pos, iarr));
                    ReturnArgs(iarr);
                    break;
                }

                case Opcode.EQ_P: {
                    _intrinsicName = "eq?"; _intrinsicPos = instruction.pos;
                    object ib = Pop(), ia = Pop();
                    Push(PrimitiveEqP.Eq(ia, ib) ? Value.T : Value.F);
                    break;
                }

                case Opcode.EQV_P: {
                    _intrinsicName = "eqv?"; _intrinsicPos = instruction.pos;
                    object ib = Pop(), ia = Pop();
                    Push(PrimitiveEqvP.Eqv(ia, ib) ? Value.T : Value.F);
                    break;
                }

                case Opcode.VECTOR_REF: {
                    _intrinsicName = "vector-ref"; _intrinsicPos = instruction.pos;
                    object idx = Pop();
                    object vec = Pop();
                    Push(Value.AsVector(vec)[IntegerMath.ToInt(idx)]);
                    break;
                }

                case Opcode.VECTOR_SET: {
                    _intrinsicName = "vector-set!"; _intrinsicPos = instruction.pos;
                    object val = Pop();
                    object idx = Pop();
                    object vec = Pop();
                    Value.AsVector(vec)[IntegerMath.ToInt(idx)] = val;
                    Push(new Values());
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
            if (e.schemeCallStack == null)
                e.schemeCallStack = ExtractCallStack();
            if (exceptionHandlers != Value.NIL)
            {
                object condition = (object?)e.errorObject ?? new ErrorObject(e.Message, Array.Empty<object>());
                SetupRaiseCall(condition);
                goto continueExecution;
            }
            sp = savedSp;
            winders = savedWinders;
            exceptionHandlers = savedExceptionHandlers;
            throw;
        }
        catch (InvalidCastException)
        {
            string name = _intrinsicName ?? "intrinsic";
            var err = new SchemeError(_intrinsicPos, "Failed in " + name + ": wrong argument type");
            err.schemeCallStack = ExtractCallStack();
            if (exceptionHandlers != Value.NIL)
            {
                object condition = new ErrorObject(err.Message, Array.Empty<object>());
                SetupRaiseCall(condition);
                goto continueExecution;
            }
            sp = savedSp;
            winders = savedWinders;
            exceptionHandlers = savedExceptionHandlers;
            throw err;
        }
        return Pop();
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
