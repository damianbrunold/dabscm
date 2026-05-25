package scheme;

import java.math.BigInteger;
import java.util.HashMap;
import java.util.ArrayList;
import java.util.List;
import java.util.Arrays;
import scheme.primitives.*;

public class VM {

    private Modules modules;
    private Lambda fn;
    private int ip;
    private Object env = Value.NIL;

    // Opt A: array-based stack (eliminates one Pair allocation per push)
    private Object[] stackArr = new Object[512];
    private int sp = 0;

    private int nargs = 0;
    private int flattened = 0;
    private String intrinsicName;   // set before each intrinsic for error messages
    private SourcePos intrinsicPos;

    public HashMap<String, Integer> call_counts = new HashMap<>();
    public Object winders = Value.NIL;
    public Object exceptionHandlers = Value.NIL;
    public static ThreadLocal<VM> current = new ThreadLocal<>();

    private final Lambda raiseReturnedLambda;

    // Static primitive instances for intrinsic fallbacks (variable-arity / edge-case paths)
    private static final PrimitiveAdd S_ADD = new PrimitiveAdd();
    private static final PrimitiveSub S_SUB = new PrimitiveSub();
    private static final PrimitiveMul S_MUL = new PrimitiveMul();
    private static final PrimitiveDiv S_DIV = new PrimitiveDiv();
    private static final PrimitiveNumequal S_NUM_EQ = new PrimitiveNumequal();
    private static final PrimitiveNumless S_NUM_LT = new PrimitiveNumless();
    private static final PrimitiveNumgreater S_NUM_GT = new PrimitiveNumgreater();
    private static final PrimitiveNumlessequal S_NUM_LTE = new PrimitiveNumlessequal();
    private static final PrimitiveNumgreaterequal S_NUM_GTE = new PrimitiveNumgreaterequal();

    private static double vmToReal(Object v) {
        if (v instanceof Long) return (double)(long)(Long)v;
        if (Value.isBigInteger(v)) return IntegerMath.toDouble(v);
        if (v instanceof Rational) return ((Rational)v).toDouble();
        return (double)(Double)v;
    }

    // Opt C: per-VM pool of exact-size argument arrays (eliminates new Object[n] per primitive call)
    private static final int MAX_POOL_SIZE = 16;
    private static final int MAX_POOL_DEPTH = 8;
    private final Object[][] pool = new Object[(MAX_POOL_SIZE + 1) * MAX_POOL_DEPTH][];
    private final int[] poolDepths = new int[MAX_POOL_SIZE + 1];

    public VM(Modules modules) {
        this.modules = modules;
        List<Instruction> code = new ArrayList<>();
        code.add(new Instruction(Opcode.HANDLER_RETURNED));
        this.raiseReturnedLambda = new Lambda(Value.NIL, code);
        this.raiseReturnedLambda.name = "raise-returned";
    }

    private Object[] rentArgs(int n) {
        if (n <= MAX_POOL_SIZE && poolDepths[n] > 0)
            return pool[n * MAX_POOL_DEPTH + --poolDepths[n]];
        return new Object[n];
    }

    private void returnArgs(Object[] arr) {
        int n = arr.length;
        if (n <= MAX_POOL_SIZE && poolDepths[n] < MAX_POOL_DEPTH) {
            Arrays.fill(arr, null);
            pool[n * MAX_POOL_DEPTH + poolDepths[n]++] = arr;
        }
    }

    private void setupRaiseCall(Object condition) {
        Pair hl = Value.asPair(exceptionHandlers);
        Object handler = hl.car;
        exceptionHandlers = hl.cdr;

        if (handler instanceof Lambda) {
            Lambda lam = (Lambda) handler;
            push(new ReturnAddress(0, raiseReturnedLambda, Value.NIL));
            push(condition);
            nargs = 1;
            fn = lam;
            ip = 0;
            env = lam.env;
        } else if (handler instanceof Primitive) {
            Primitive prim = (Primitive) handler;
            try {
                prim.apply(null, new Object[] { condition });
            } catch (SchemeError inner) {
                Object innerCond = inner.errorObject != null ? inner.errorObject
                    : new ErrorObject(inner.getMessage(), new Object[0]);
                if (exceptionHandlers != Value.NIL) {
                    setupRaiseCall(innerCond);
                } else {
                    if (inner.schemeCallStack == null) inner.schemeCallStack = extractCallStack();
                    throw inner;
                }
                return;
            }
            ErrorObject errCond = new ErrorObject("raise: exception handler returned", new Object[] { condition });
            if (exceptionHandlers != Value.NIL) {
                setupRaiseCall(errCond);
            } else {
                throw new SchemeError((SourcePos) null, errCond);
            }
        } else {
            throw new SchemeError((SourcePos) null, "with-exception-handler: handler is not a procedure");
        }
    }

    private Object elt(Object list, int n) {
        for (int i = 0; i < n; i++) {
            list = Value.asPair(list).cdr;
        }
        return Value.asPair(list).car;
    }

    // Opt B: frames are now Object[] instead of Pair chains — O(1) variable access
    private Object getenv(int frame, int var) {
        if (frame == 0) return ((Object[]) Value.asPair(env).car)[var];
        return ((Object[]) elt(env, frame))[var];
    }

    private void setenv(int frame, int var, Object value) {
        ((Object[]) elt(env, frame))[var] = value;
    }

    // Opt A: array-based stack operations
    private void push(Object value) {
        if (sp == stackArr.length) {
            Object[] bigger = new Object[stackArr.length * 2];
            System.arraycopy(stackArr, 0, bigger, 0, sp);
            stackArr = bigger;
        }
        stackArr[sp++] = value;
    }

    private Object pop() {
        Object value = stackArr[--sp];
        stackArr[sp] = null; // clear for GC
        return value;
    }

    private Object top() { return stackArr[sp - 1]; }
    private Object second() { return stackArr[sp - 2]; }

    private Object primaryValue(Object value) {
        if (Value.isValues(value)) {
            Object[] vals = Value.asValues(value).values;
            if (vals.length == 0) return value; // empty values = unspecified, pass through
            return vals[0];
        }
        return value;
    }

    private List<SchemeCallFrame> extractCallStack() {
        List<SchemeCallFrame> frames = new ArrayList<>();
        SourcePos currentPos = (fn != null && ip > 0 && ip - 1 < fn.code.size())
            ? fn.code.get(ip - 1).pos : null;
        frames.add(new SchemeCallFrame(fn != null ? fn.name : null, currentPos));
        for (int i = sp - 1; i >= 0; i--) {
            if (stackArr[i] instanceof ReturnAddress) {
                ReturnAddress addr = (ReturnAddress) stackArr[i];
                SourcePos callPos = (addr.ip > 0 && addr.ip - 1 < addr.fn.code.size())
                    ? addr.fn.code.get(addr.ip - 1).pos : null;
                frames.add(new SchemeCallFrame(addr.fn.name, callPos));
            }
        }
        return frames;
    }

    @SuppressWarnings("unchecked")
    public Object execute(Lambda func) {
        VM savedCurrent = VM.current.get();
        VM.current.set(this);
        try {
        if (SchemeThread.currentThread.get() == null) {
            SchemeThread primordial = new SchemeThread(null, modules);
            primordial.name = Value.intern("primordial");
            primordial.state = SchemeThread.State.STARTED;
            SchemeThread.currentThread.set(primordial);
        }
        int savedSp = sp;
        Object savedWinders = winders;
        Object savedExceptionHandlers = exceptionHandlers;
        push(new ReturnAddress(func.code.size(), func, env));
        this.fn = func;
        this.ip = 0;
        this.nargs = 0;
        boolean continueExecution;
        do {
        continueExecution = false;
        try {
        while (ip < this.fn.code.size()) {
            Instruction instruction = this.fn.code.get(ip++);
            switch (instruction.opcode) {
                case LVAR:
                    push(getenv((int) instruction.arg1,
                                (int) instruction.arg2));
                    break;

                case LSET:
                    setenv((int) instruction.arg1,
                           (int) instruction.arg2,
                           primaryValue(top()));
                    break;

                case GVAR: {
                    Cell cell = instruction.cachedCell;
                    if (cell != null && instruction.cachedCellGeneration == modules.cacheGeneration) {
                        push(cell.value);
                        break;
                    }
                    try {
                        String moduleName = (String) instruction.arg2;
                        String symbol = Value.asSymbol(instruction.arg1);
                        Module module = modules.getModuleRequired(instruction.pos, moduleName);
                        Cell resolved = module.resolveCell(symbol);
                        if (resolved == null) {
                            throw new SchemeError(instruction.pos, module.getName() + ": ~a is not bound", symbol);
                        }
                        instruction.cachedCell = resolved;
                        instruction.cachedCellGeneration = modules.cacheGeneration;
                        push(resolved.value);
                    } catch (SchemeError e) {
                        throw e;
                    } catch (Exception e) {
                        throw new SchemeError(instruction.pos, "internal error");
                    }
                    break;
                }

                case GSET: {
                    Object value = primaryValue(top());
                    Cell cachedCell = instruction.cachedCell;
                    if (cachedCell != null
                        && instruction.cachedCellGeneration == modules.cacheGeneration
                        && !Scheme.strictImports) {
                        cachedCell.value = value;
                        if (Value.isLambda(value)) {
                            Value.asLambda(value).name = instruction.arg1.toString();
                        }
                        break;
                    }
                    Module module = modules.getModuleRequired(instruction.pos, (String) instruction.arg2);
                    String symbol = Value.asSymbol(instruction.arg1);
                    if (Scheme.strictImports && "user program".equals(module.getName())) {
                        String origin = module.provenance.get(symbol);
                        if (origin != null && !origin.equals(module.getName()) && !"scm core".equals(origin)) {
                            throw new SchemeError(instruction.pos,
                                "program: cannot redefine imported symbol '~a' from '~a'",
                                symbol, origin);
                        }
                    }
                    module.bind(symbol, value);
                    instruction.cachedCell = module.resolveCell(symbol);
                    instruction.cachedCellGeneration = modules.cacheGeneration;
                    if (Value.isLambda(value)) {
                        Value.asLambda(value).name = instruction.arg1.toString();
                    }
                    break;
                }

                case POP:
                    pop();
                    break;

                case CONST:
                    push(instruction.arg1);
                    break;

                case JUMP:
                    ip = (int) instruction.arg1;
                    break;

                case FJUMP:
                    if (pop() == Value.F) ip = (int) instruction.arg1;
                    break;

                case TJUMP:
                    if (pop() != Value.F) ip = (int) instruction.arg1;
                    break;

                case SAVE:
                    push(new ReturnAddress((int) instruction.arg1, this.fn, env));
                    break;

                case RETURN: {
                    ReturnAddress address = (ReturnAddress) second();
                    this.fn = address.fn;
                    env = address.env;
                    ip = address.ip;
                    Object value = pop();
                    pop();
                    push(value);
                    break;
                }

                case CALLJ: {
                    SchemeThread ct = SchemeThread.currentThread.get();
                    if (ct != null && ct.terminated)
                        throw new SchemeError("thread terminated");
                    int argcount = (int) instruction.arg1;
                    if (argcount == -1) {
                        argcount = flattened;
                        flattened = 0;
                    }
                    env = Value.asPair(env).cdr; // discard top frame
                    Object f = pop();
                    if (Value.isLambda(f)) {
                        // countCall(Value.DisplayRep(f));
                        this.fn = Value.asLambda(f);
                        env = fn.env;
                        ip = 0;
                        nargs = argcount;
                    } else if (Value.isPrimitive(f)) {
                        // countCall(Value.DisplayRep(f));
                        // Opt C: use pooled arg arrays
                        Object[] args = rentArgs(argcount);
                        nargs = args.length;
                        for (int i = args.length - 1; i >= 0; i--) {
                            args[i] = primaryValue(pop());
                        }
                        Object result;
                        try {
                            result = Value.asPrimitive(f).apply(instruction.pos, args);
                        } catch (SchemeError e) {
                            returnArgs(args);
                            throw e;
                        } catch (ClassCastException e) {
                            returnArgs(args);
                            throw new SchemeError(instruction.pos,
                                                  "Failed in " + Value.asPrimitive(f).name()
                                                  + ": wrong argument type");
                        } catch (Exception e) {
                            returnArgs(args);
                            throw new SchemeError(instruction.pos,
                                                  "Failed in " + Value.asPrimitive(f).name()
                                                  + ": " + e.getMessage());
                        }
                        // If a primitive stored the args array directly in the result (e.g. `values`),
                        // clone it before clearing so the result isn't corrupted.
                        if (result instanceof Values && ((Values) result).values == args)
                            ((Values) result).values = args.clone();
                        returnArgs(args);
                        push(result);
                        ReturnAddress address = (ReturnAddress) second();
                        this.fn = address.fn;
                        env = address.env;
                        ip = address.ip;
                        Object val = pop();
                        pop();
                        push(val);
                    } else {
                        throw new SchemeError(instruction.pos, f + " is not a function, cannot apply");
                    }
                    break;
                }

                case ARGS: {
                    if (nargs != (int) instruction.arg1)
                        throw new SchemeError(instruction.pos,
                                              (fn.name != null ? fn.name + " " : "")
                                              + "Wrong number of arguments: "
                                              + instruction.arg1 + " expected, "
                                              + nargs + " supplied");
                    // Opt B: build Object[] frame instead of Pair chain
                    Object[] frame = new Object[nargs];
                    for (int i = nargs - 1; i >= 0; i--) frame[i] = pop();
                    env = new Pair(frame, env);
                    break;
                }

                case EXTEND: {
                    int n = (int) instruction.arg1;
                    Object[] frame = new Object[n];
                    for (int i = n - 1; i >= 0; i--) frame[i] = pop();
                    env = new Pair(frame, env);
                    break;
                }

                case ARGSDOT: {
                    int fixedArgs = (int) instruction.arg1;
                    if (nargs < fixedArgs)
                        throw new SchemeError(instruction.pos,
                                              (fn.name != null ? fn.name + " " : "")
                                              + "Wrong number of arguments: "
                                              + instruction.arg1 + " or more expected, "
                                              + nargs + " supplied");
                    // Opt B: build Object[] frame; rest list remains a Pair chain (Scheme list)
                    Object rest = Value.NIL;
                    for (int i = 0; i < nargs - fixedArgs; i++) {
                        rest = new Pair(pop(), rest);
                    }
                    Object[] frame = new Object[fixedArgs + 1];
                    frame[fixedArgs] = rest;
                    for (int i = fixedArgs - 1; i >= 0; i--) frame[i] = pop();
                    env = new Pair(frame, env);
                    break;
                }

                case ARGMV: {
                    // Opt B: build Object[] frame
                    if (nargs == 1) {
                        env = new Pair(new Object[] { pop() }, env);
                    } else {
                        Values mv = new Values();
                        mv.values = new Object[nargs];
                        for (int i = nargs - 1; i >= 0; i--) {
                            mv.values[i] = pop();
                        }
                        env = new Pair(new Object[] { mv }, env);
                    }
                    break;
                }

                case FN: {
                    Pair fn_pair = Value.asPair(instruction.arg1);
                    List<Instruction> fn_instructions = (List<Instruction>) fn_pair.sixth();
                    Lambda new_lambda = new Lambda(env, fn_instructions);
                    if (fn_pair.length() > 6) new_lambda.doc = fn_pair.eight().toString();
                    push(new_lambda);
                    break;
                }

                case SETCC: {
                    // Opt A: restore array stack from captured Pair chain
                    Object savedStack = top();
                    sp = 0;
                    for (Object p = savedStack; p != Value.NIL; p = Value.asPair(p).cdr)
                        push(Value.asPair(p).car);
                    break;
                }

                case CC: {
                    // Opt A: serialize array stack to Pair chain for capture
                    Object capturedStack = Value.NIL;
                    for (int i = sp - 1; i >= 0; i--)
                        capturedStack = new Pair(stackArr[i], capturedStack);
                    List<Instruction> newcode = new ArrayList<>();
                    newcode.add(new Instruction(Opcode.ARGMV));
                    newcode.add(new Instruction(Opcode.LVAR, 1, 0));
                    newcode.add(new Instruction(Opcode.SETCC));
                    newcode.add(new Instruction(Opcode.LVAR, 0, 0));
                    newcode.add(new Instruction(Opcode.RETURN));
                    // Opt B: env frame must be Object[]
                    Object capturedEnv = new Pair(new Object[] { capturedStack }, Value.NIL);
                    push(new Lambda(capturedEnv, newcode));
                    break;
                }

                case FLATTEN_APPLY: {
                    List<Object> args = new ArrayList<>();
                    Object restObj = getenv((int) instruction.arg1, (int) instruction.arg2);
                    if (restObj == Value.NIL)
                        throw new SchemeError(instruction.pos, "apply: not enough arguments");
                    Object pair = restObj;
                    while (pair != Value.NIL) {
                        if (Value.asPair(pair).cdr == Value.NIL) {
                            if (!Value.isPair(Value.asPair(pair).car) && !Value.isNil(Value.asPair(pair).car))
                                throw new SchemeError(instruction.pos, "apply: last argument must be a list");
                            pair = Value.asPair(pair).car;
                            while (pair != Value.NIL) {
                                args.add(Value.asPair(pair).car);
                                pair = Value.asPair(pair).cdr;
                            }
                            break;
                        } else {
                            args.add(Value.asPair(pair).car);
                            pair = Value.asPair(pair).cdr;
                        }
                    }
                    flattened = args.size();
                    for (int i = 0; i < args.size(); i++) {
                        push(args.get(i));
                    }
                    break;
                }

                case FLATTEN_MULTVALS: {
                    Object val = pop();
                    if (Value.isValues(val)) {
                        Object[] values = Value.asValues(val).values;
                        flattened = values.length;
                        for (int i = 0; i < values.length; i++) {
                            push(values[i]);
                        }
                    } else {
                        flattened = 1;
                        push(val);
                    }
                    break;
                }

                case HANDLER_RETURNED:
                    throw new SchemeError((SourcePos) null, new ErrorObject(
                        "raise: exception handler returned", new Object[0]));

                case CAR:
                    intrinsicName = "car"; intrinsicPos = instruction.pos;
                    push(Value.asPair(pop()).car);
                    break;

                case CDR:
                    intrinsicName = "cdr"; intrinsicPos = instruction.pos;
                    push(Value.asPair(pop()).cdr);
                    break;

                case CONS: {
                    intrinsicName = "cons"; intrinsicPos = instruction.pos;
                    Object icdr = pop(), icar = pop();
                    push(new Pair(icar, icdr));
                    break;
                }

                case IS_NULL:
                    intrinsicName = "null?"; intrinsicPos = instruction.pos;
                    push(pop() == Value.NIL ? Value.T : Value.F);
                    break;

                case IS_PAIR: {
                    intrinsicName = "pair?"; intrinsicPos = instruction.pos;
                    Object ipv = pop();
                    push(Value.isPair(ipv) ? Value.T : Value.F);
                    break;
                }

                case NOT:
                    intrinsicName = "not"; intrinsicPos = instruction.pos;
                    push(pop().equals(Value.F) ? Value.T : Value.F);
                    break;

                case LVAR_ADD_IMM: {
                    long packed = (long)(Long) instruction.arg1;
                    Object val = getenv((int)(packed >> 16), (int)(packed & 0xFFFF));
                    long imm = (long)(Long) instruction.arg2;
                    if (val instanceof Long) {
                        try { push(Math.addExact((long)(Long)val, imm)); }
                        catch (ArithmeticException e) { push(IntegerMath.genericAdd(val, imm)); }
                        break;
                    }
                    if (Value.isBigInteger(val)) { push(IntegerMath.genericAdd(val, imm)); break; }
                    if (val instanceof Double) { push((double)(Double)val + (double)imm); break; }
                    if (val instanceof Complex) { push(Complex.add(val, imm)); break; }
                    push(Rational.add(val, imm)); break;
                }

                case LVAR_SUB_IMM: {
                    long packed = (long)(Long) instruction.arg1;
                    Object val = getenv((int)(packed >> 16), (int)(packed & 0xFFFF));
                    long imm = (long)(Long) instruction.arg2;
                    if (val instanceof Long) {
                        try { push(Math.subtractExact((long)(Long)val, imm)); }
                        catch (ArithmeticException e) { push(IntegerMath.genericSub(val, imm)); }
                        break;
                    }
                    if (Value.isBigInteger(val)) { push(IntegerMath.genericSub(val, imm)); break; }
                    if (val instanceof Double) { push((double)(Double)val - (double)imm); break; }
                    if (val instanceof Complex) { push(Complex.sub(val, imm)); break; }
                    push(Rational.sub(val, imm)); break;
                }

                case ADD: {
                    intrinsicName = "+"; intrinsicPos = instruction.pos;
                    int n = (int) instruction.arg1;
                    if (n == 0) { push(0L); break; }
                    if (n == 2) {
                        Object ib = pop(), ia = pop();
                        if (ia instanceof Long && ib instanceof Long) {
                            try { push(Math.addExact((long)(Long)ia, (long)(Long)ib)); }
                            catch (ArithmeticException e) { push(IntegerMath.genericAdd(ia, ib)); }
                            break;
                        }
                        if (Value.isInteger(ia) && Value.isInteger(ib)) { push(IntegerMath.genericAdd(ia, ib)); break; }
                        if (ia instanceof Double || ib instanceof Double) {
                            if (ia instanceof Complex || ib instanceof Complex) { push(Complex.add(ia, ib)); break; }
                            push(vmToReal(ia) + vmToReal(ib)); break;
                        }
                        if (ia instanceof Complex || ib instanceof Complex) { push(Complex.add(ia, ib)); break; }
                        push(Rational.add(ia, ib)); break;
                    }
                    Object[] iarr = rentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = pop();
                    push(S_ADD.apply(instruction.pos, iarr));
                    returnArgs(iarr);
                    break;
                }

                case SUB: {
                    intrinsicName = "-"; intrinsicPos = instruction.pos;
                    int n = (int) instruction.arg1;
                    if (n == 1) {
                        Object ia = pop();
                        if (ia instanceof Long) { push(IntegerMath.negate((long)(Long)ia)); break; }
                        if (Value.isBigInteger(ia)) { push(IntegerMath.genericNegate(ia)); break; }
                        if (ia instanceof Double) { push(-(double)(Double)ia); break; }
                        if (ia instanceof Complex) { push(Complex.negate(ia)); break; }
                        push(Rational.sub(0L, ia)); break;
                    }
                    if (n == 2) {
                        Object ib = pop(), ia = pop();
                        if (ia instanceof Long && ib instanceof Long) {
                            try { push(Math.subtractExact((long)(Long)ia, (long)(Long)ib)); }
                            catch (ArithmeticException e) { push(IntegerMath.genericSub(ia, ib)); }
                            break;
                        }
                        if (Value.isInteger(ia) && Value.isInteger(ib)) { push(IntegerMath.genericSub(ia, ib)); break; }
                        if (ia instanceof Double || ib instanceof Double) {
                            if (ia instanceof Complex || ib instanceof Complex) { push(Complex.sub(ia, ib)); break; }
                            push(vmToReal(ia) - vmToReal(ib)); break;
                        }
                        if (ia instanceof Complex || ib instanceof Complex) { push(Complex.sub(ia, ib)); break; }
                        push(Rational.sub(ia, ib)); break;
                    }
                    Object[] iarr = rentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = pop();
                    push(S_SUB.apply(instruction.pos, iarr));
                    returnArgs(iarr);
                    break;
                }

                case MUL: {
                    intrinsicName = "*"; intrinsicPos = instruction.pos;
                    int n = (int) instruction.arg1;
                    if (n == 0) { push(1L); break; }
                    if (n == 2) {
                        Object ib = pop(), ia = pop();
                        if (ia instanceof Long && ib instanceof Long) {
                            try { push(Math.multiplyExact((long)(Long)ia, (long)(Long)ib)); }
                            catch (ArithmeticException e) { push(IntegerMath.genericMul(ia, ib)); }
                            break;
                        }
                        if (Value.isInteger(ia) && Value.isInteger(ib)) { push(IntegerMath.genericMul(ia, ib)); break; }
                        if (ia instanceof Double || ib instanceof Double) {
                            if (ia instanceof Complex || ib instanceof Complex) { push(Complex.mul(ia, ib)); break; }
                            push(vmToReal(ia) * vmToReal(ib)); break;
                        }
                        if (ia instanceof Complex || ib instanceof Complex) { push(Complex.mul(ia, ib)); break; }
                        push(Rational.mul(ia, ib)); break;
                    }
                    Object[] iarr = rentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = pop();
                    push(S_MUL.apply(instruction.pos, iarr));
                    returnArgs(iarr);
                    break;
                }

                case DIV: {
                    intrinsicName = "/"; intrinsicPos = instruction.pos;
                    int n = (int) instruction.arg1;
                    if (n == 2) {
                        Object ib = pop(), ia = pop();
                        if (ia instanceof Long && ib instanceof Long) {
                            long ibl = (long)(Long)ib;
                            if (ibl == 0) throw new SchemeError(instruction.pos, "/: Division by zero");
                            push(Rational.div(ia, ib)); break;
                        }
                        if (ia instanceof Double || ib instanceof Double) {
                            if (ia instanceof Complex || ib instanceof Complex) { push(Complex.div(ia, ib)); break; }
                            double dib = vmToReal(ib);
                            if (dib == 0.0) throw new SchemeError(instruction.pos, "/: Division by ~s", dib);
                            push(vmToReal(ia) / dib); break;
                        }
                        if (ia instanceof Complex || ib instanceof Complex) { push(Complex.div(ia, ib)); break; }
                        push(Rational.div(ia, ib)); break;
                    }
                    Object[] iarr = rentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = pop();
                    push(S_DIV.apply(instruction.pos, iarr));
                    returnArgs(iarr);
                    break;
                }

                case NUM_EQ: {
                    intrinsicName = "="; intrinsicPos = instruction.pos;
                    int n = (int) instruction.arg1;
                    if (n == 2) {
                        Object ib = pop(), ia = pop();
                        if (ia instanceof Long && ib instanceof Long) { push((long)(Long)ia == (long)(Long)ib ? Value.T : Value.F); break; }
                        if (Value.isInteger(ia) && Value.isInteger(ib)) { push(IntegerMath.genericEquals(ia, ib) ? Value.T : Value.F); break; }
                        if (ia instanceof Double && ib instanceof Double) { push((double)(Double)ia == (double)(Double)ib ? Value.T : Value.F); break; }
                        if (ia instanceof Complex || ib instanceof Complex) { push(Complex.numericEquals(ia, ib) ? Value.T : Value.F); break; }
                        push(Primitive.mixedNumericEquals(ia, ib) ? Value.T : Value.F); break;
                    }
                    Object[] iarr = rentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = pop();
                    push(S_NUM_EQ.apply(instruction.pos, iarr));
                    returnArgs(iarr);
                    break;
                }

                case NUM_LT: {
                    intrinsicName = "<"; intrinsicPos = instruction.pos;
                    int n = (int) instruction.arg1;
                    if (n == 2) {
                        Object ib = pop(), ia = pop();
                        if (ia instanceof Long && ib instanceof Long) { push((long)(Long)ia < (long)(Long)ib ? Value.T : Value.F); break; }
                        if (Value.isInteger(ia) && Value.isInteger(ib)) { push(IntegerMath.compare(ia, ib) < 0 ? Value.T : Value.F); break; }
                        if (ia instanceof Complex || ib instanceof Complex) throw new SchemeError(instruction.pos, "<: complex numbers are not ordered");
                        push(Primitive.mixedNumericCompare(ia, ib) < 0 ? Value.T : Value.F); break;
                    }
                    Object[] iarr = rentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = pop();
                    push(S_NUM_LT.apply(instruction.pos, iarr));
                    returnArgs(iarr);
                    break;
                }

                case NUM_GT: {
                    intrinsicName = ">"; intrinsicPos = instruction.pos;
                    int n = (int) instruction.arg1;
                    if (n == 2) {
                        Object ib = pop(), ia = pop();
                        if (ia instanceof Long && ib instanceof Long) { push((long)(Long)ia > (long)(Long)ib ? Value.T : Value.F); break; }
                        if (Value.isInteger(ia) && Value.isInteger(ib)) { push(IntegerMath.compare(ia, ib) > 0 ? Value.T : Value.F); break; }
                        if (ia instanceof Complex || ib instanceof Complex) throw new SchemeError(instruction.pos, ">: complex numbers are not ordered");
                        push(Primitive.mixedNumericCompare(ia, ib) > 0 ? Value.T : Value.F); break;
                    }
                    Object[] iarr = rentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = pop();
                    push(S_NUM_GT.apply(instruction.pos, iarr));
                    returnArgs(iarr);
                    break;
                }

                case NUM_LTE: {
                    intrinsicName = "<="; intrinsicPos = instruction.pos;
                    int n = (int) instruction.arg1;
                    if (n == 2) {
                        Object ib = pop(), ia = pop();
                        if (ia instanceof Long && ib instanceof Long) { push((long)(Long)ia <= (long)(Long)ib ? Value.T : Value.F); break; }
                        if (Value.isInteger(ia) && Value.isInteger(ib)) { push(IntegerMath.compare(ia, ib) <= 0 ? Value.T : Value.F); break; }
                        if (ia instanceof Complex || ib instanceof Complex) throw new SchemeError(instruction.pos, "<=: complex numbers are not ordered");
                        push(Primitive.mixedNumericCompare(ia, ib) <= 0 ? Value.T : Value.F); break;
                    }
                    Object[] iarr = rentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = pop();
                    push(S_NUM_LTE.apply(instruction.pos, iarr));
                    returnArgs(iarr);
                    break;
                }

                case NUM_GTE: {
                    intrinsicName = ">="; intrinsicPos = instruction.pos;
                    int n = (int) instruction.arg1;
                    if (n == 2) {
                        Object ib = pop(), ia = pop();
                        if (ia instanceof Long && ib instanceof Long) { push((long)(Long)ia >= (long)(Long)ib ? Value.T : Value.F); break; }
                        if (Value.isInteger(ia) && Value.isInteger(ib)) { push(IntegerMath.compare(ia, ib) >= 0 ? Value.T : Value.F); break; }
                        if (ia instanceof Complex || ib instanceof Complex) throw new SchemeError(instruction.pos, ">=: complex numbers are not ordered");
                        push(Primitive.mixedNumericCompare(ia, ib) >= 0 ? Value.T : Value.F); break;
                    }
                    Object[] iarr = rentArgs(n);
                    for (int i = n - 1; i >= 0; i--) iarr[i] = pop();
                    push(S_NUM_GTE.apply(instruction.pos, iarr));
                    returnArgs(iarr);
                    break;
                }

                case EQ_P: {
                    intrinsicName = "eq?"; intrinsicPos = instruction.pos;
                    Object ib = pop(), ia = pop();
                    push(PrimitiveEqP.eq(ia, ib) ? Value.T : Value.F);
                    break;
                }

                case EQV_P: {
                    intrinsicName = "eqv?"; intrinsicPos = instruction.pos;
                    Object ib = pop(), ia = pop();
                    push(PrimitiveEqvP.eqv(ia, ib) ? Value.T : Value.F);
                    break;
                }

                case VECTOR_REF: {
                    intrinsicName = "vector-ref"; intrinsicPos = instruction.pos;
                    Object idx = pop();
                    Object vec = pop();
                    push(Value.asVector(vec)[IntegerMath.toInt(idx)]);
                    break;
                }

                case VECTOR_SET: {
                    intrinsicName = "vector-set!"; intrinsicPos = instruction.pos;
                    Object val = pop();
                    Object idx = pop();
                    Object vec = pop();
                    Value.asVector(vec)[IntegerMath.toInt(idx)] = val;
                    push(new Values());
                    break;
                }

                default:
                    throw new SchemeError(instruction.pos,
                                          "Unknown opcode " + instruction.opcode);
            }
        }
        } catch (SchemeError e) {
            if (e.schemeCallStack == null)
                e.schemeCallStack = extractCallStack();
            if (exceptionHandlers != Value.NIL) {
                Object condition = e.errorObject != null ? e.errorObject
                    : new ErrorObject(e.getMessage(), new Object[0]);
                setupRaiseCall(condition);
                continueExecution = true;
            } else {
                sp = savedSp;
                winders = savedWinders;
                exceptionHandlers = savedExceptionHandlers;
                throw e;
            }
        } catch (ClassCastException cce) {
            String name = intrinsicName != null ? intrinsicName : "intrinsic";
            SchemeError err = new SchemeError(intrinsicPos, "Failed in " + name + ": wrong argument type");
            err.schemeCallStack = extractCallStack();
            if (exceptionHandlers != Value.NIL) {
                Object condition = new ErrorObject(err.getMessage(), new Object[0]);
                setupRaiseCall(condition);
                continueExecution = true;
            } else {
                sp = savedSp;
                winders = savedWinders;
                exceptionHandlers = savedExceptionHandlers;
                throw err;
            }
        }
        } while (continueExecution);
        return pop();
        } finally {
            VM.current.set(savedCurrent);
        }
    }

    @SuppressWarnings("unused")
    private void countCall(String s) {
        if (call_counts.containsKey(s)) {
            call_counts.put(s, call_counts.get(s) + 1);
        } else {
            call_counts.put(s, 1);
        }
    }
}
