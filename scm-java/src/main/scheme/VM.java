package scheme;

import java.math.BigInteger;
import java.util.HashMap;
import java.util.ArrayList;
import java.util.List;
import java.util.Arrays;
import scheme.primitives.*;
import scheme.jit.Activation;
import scheme.jit.ContinuationJump;
import scheme.jit.FrameCapture;
import scheme.jit.Jit;
import scheme.jit.Rt;
import scheme.jit.TailCall;

public class VM {

    public final Modules modules;

    // The VM state. While execute runs it lives in execute's locals; these
    // fields hold it only where code outside the dispatch loop needs it
    // (setupRaiseCall, extractCallStack) and between executes.
    private Lambda fn;
    private int ip;
    private Object env = Value.NIL;

    // Opt A: array-based stack (eliminates one Pair allocation per push)
    private Object[] stackArr = new Object[512];
    private int sp = 0;

    private int nargs = 0;
    private int flattened = 0;

    public HashMap<String, Integer> call_counts = new HashMap<>();
    public Object winders = Value.NIL;
    public Object exceptionHandlers = Value.NIL;
    public static ThreadLocal<VM> current = new ThreadLocal<>();

    public final Lambda raiseReturnedLambda;

    // Static primitive instances for intrinsic fallbacks (variable-arity / edge-case paths)
    public static final PrimitiveAdd S_ADD = new PrimitiveAdd();
    public static final PrimitiveSub S_SUB = new PrimitiveSub();
    public static final PrimitiveMul S_MUL = new PrimitiveMul();
    public static final PrimitiveDiv S_DIV = new PrimitiveDiv();
    public static final PrimitiveNumequal S_NUM_EQ = new PrimitiveNumequal();
    public static final PrimitiveNumless S_NUM_LT = new PrimitiveNumless();
    public static final PrimitiveNumgreater S_NUM_GT = new PrimitiveNumgreater();
    public static final PrimitiveNumlessequal S_NUM_LTE = new PrimitiveNumlessequal();
    public static final PrimitiveNumgreaterequal S_NUM_GTE = new PrimitiveNumgreaterequal();

    // The Scheme name of an opcode that can fail with a wrong argument type,
    // for the error message; null for the VM's internal opcodes.
    public static String opcodeErrorName(Opcode op) {
        switch (op) {
            case CAR: case LVAR_CAR: return "car";
            case CDR: case LVAR_CDR: return "cdr";
            case CONS: return "cons";
            case IS_NULL: return "null?";
            case IS_PAIR: return "pair?";
            case NOT: return "not";
            case ADD: case LVAR_ADD_IMM: return "+";
            case SUB: case LVAR_SUB_IMM: return "-";
            case MUL: return "*";
            case DIV: return "/";
            case NUM_EQ: return "=";
            case NUM_LT: return "<";
            case NUM_GT: return ">";
            case NUM_LTE: return "<=";
            case NUM_GTE: return ">=";
            case EQ_P: return "eq?";
            case EQV_P: return "eqv?";
            case VECTOR_REF: case LVAR_VREF: return "vector-ref";
            case VECTOR_SET: return "vector-set!";
            case FLATTEN_APPLY: return "apply";
            default: return null;
        }
    }

    // "Failed in <name>: wrong argument type", with the offending value as
    // irritant when the cast site reported it (WrongTypeException).
    public static SchemeError wrongArgumentTypeError(SourcePos pos, String name, ClassCastException e) {
        String message = "Failed in " + name + ": wrong argument type";
        if (!(e instanceof WrongTypeException))
            return new SchemeError(pos, new ErrorObject(message, new Object[0]));
        WrongTypeException wt = (WrongTypeException) e;
        if (WrongTypeException.isHostValue(wt.value))
            message += " (host " + wt.value.getClass().getSimpleName() + ", not a Scheme " + wt.expected + ")";
        return new SchemeError(pos, new ErrorObject(message, new Object[] { wt.value }));
    }

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

    // An environment is a chain of frames: Object[] with the parent
    // environment in slot 0 and the frame's variables from slot 1.
    // LOOP: the n arguments on top of the stack as a new frame whose parent
    // is the frame depth levels up (kept out of execute, see its size note)
    private static Object[] loopFrame(Object env, int depth, Object[] stack, int sp, int n) {
        Object[] parent = (Object[]) env;
        for (int i = depth; i > 0; i--) parent = (Object[]) parent[0];
        Object[] frame = new Object[n + 1];
        for (int i = n; i >= 1; i--) { frame[i] = stack[--sp]; stack[sp] = null; }
        frame[0] = parent;
        return frame;
    }

    private static Object getenv(Object env, int frame, int var) {
        Object[] f = (Object[]) env;
        for (int i = 0; i < frame; i++) f = (Object[]) f[0];
        return f[var + 1];
    }

    private static void setenv(Object env, int frame, int var, Object value) {
        Object[] f = (Object[]) env;
        for (int i = 0; i < frame; i++) f = (Object[]) f[0];
        f[var + 1] = value;
    }

    // The dispatch loop pushes without a bounds check: an instruction
    // pushes at most one value and jumps only forward, so the rest of the
    // current function needs at most one slot per remaining instruction.
    // That room is made whenever a function is entered or returned to, at
    // backward jumps (only possible in code from set-code!) and by the
    // instructions that push many values.
    private Object[] ensureStack(Object[] stack, int needed) {
        if (needed <= stack.length) return stack;
        Object[] bigger = new Object[Math.max(stack.length * 2, needed)];
        System.arraycopy(stack, 0, bigger, 0, stack.length);
        stackArr = bigger;
        return bigger;
    }

    // Opt A: array-based stack; push for the code outside the dispatch loop
    private void push(Object value) {
        stackArr = ensureStack(stackArr, sp + 1);
        stackArr[sp++] = value;
    }

    // The binding cell of a global variable, cached in the instruction
    // (GVAR, GCALLS, GCALLJ).
    public Cell globalCell(Instruction instruction, Object symbolObj, String moduleName) {
        Cell cell = instruction.cachedCell;
        if (cell != null && instruction.cachedCellGeneration == modules.cacheGeneration)
            return cell;
        try {
            String symbol = Value.asSymbol(symbolObj);
            Module module = modules.getModuleRequired(instruction.pos, moduleName);
            Cell resolved = module.resolveCell(symbol);
            if (resolved == null) {
                throw new SchemeError(instruction.pos, module.getName() + ": ~a is not bound", symbol);
            }
            instruction.cachedCell = resolved;
            instruction.cachedCellGeneration = modules.cacheGeneration;
            return resolved;
        } catch (SchemeError e) {
            throw e;
        } catch (Exception e) {
            throw new SchemeError(instruction.pos, "internal error");
        }
    }

    // Cold paths of the dispatch loop, kept out of execute so that the JIT
    // compiles the loop itself well.

    public void globalSet(Instruction instruction, Object value) {
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
    }

    public static SchemeError arityError(Lambda fn, Instruction instruction, int nargs, String expected) {
        return new SchemeError(instruction.pos,
                               (fn.name != null ? fn.name + " " : "")
                               + "Wrong number of arguments: "
                               + instruction.arg1 + expected + " expected, "
                               + nargs + " supplied");
    }

    // Applies the primitive f to the argcount values at stack[sp..], which
    // the caller has popped; their slots are cleared.
    private Object applyPrimitive(Object f, SourcePos pos, Object[] stack, int sp, int argcount) {
        Primitive prim = Value.asPrimitive(f);
        // Opt C: use pooled arg arrays
        Object[] args = rentArgs(argcount);
        for (int i = 0; i < argcount; i++) {
            args[i] = primaryValue(stack[sp + i]);
            stack[sp + i] = null;
        }
        Object result;
        try {
            result = prim.apply(pos, args);
        } catch (SchemeError e) {
            returnArgs(args);
            throw e;
        } catch (ClassCastException e) {
            returnArgs(args);
            throw wrongArgumentTypeError(pos, prim.name(), e);
        } catch (Exception e) {
            returnArgs(args);
            throw new SchemeError(pos, "Failed in " + prim.name() + ": " + e.getMessage());
        }
        // If a primitive stored the args array directly in the result (e.g. `values`),
        // clone it before clearing so the result isn't corrupted.
        if (result instanceof Values && ((Values) result).values == args)
            ((Values) result).values = args.clone();
        returnArgs(args);
        return result;
    }

    // An arithmetic intrinsic with other than the inlined argument count:
    // the n values at stack[sp..], popped by the caller.
    private Object applyIntrinsic(Primitive prim, SourcePos pos, Object[] stack, int sp, int n) {
        Object[] iarr = rentArgs(n);
        System.arraycopy(stack, sp, iarr, 0, n);
        Object result = prim.apply(pos, iarr);
        returnArgs(iarr);
        return result;
    }

    // The two-argument arithmetic beyond fixnums without overflow.
    public static Object add2(Object ia, Object ib) {
        if (Value.isInteger(ia) && Value.isInteger(ib)) return IntegerMath.genericAdd(ia, ib);
        if (ia instanceof Double || ib instanceof Double) {
            if (ia instanceof Complex || ib instanceof Complex) return Complex.add(ia, ib);
            return vmToReal(ia) + vmToReal(ib);
        }
        if (ia instanceof Complex || ib instanceof Complex) return Complex.add(ia, ib);
        return Rational.add(ia, ib);
    }

    public static Object sub2(Object ia, Object ib) {
        if (Value.isInteger(ia) && Value.isInteger(ib)) return IntegerMath.genericSub(ia, ib);
        if (ia instanceof Double || ib instanceof Double) {
            if (ia instanceof Complex || ib instanceof Complex) return Complex.sub(ia, ib);
            return vmToReal(ia) - vmToReal(ib);
        }
        if (ia instanceof Complex || ib instanceof Complex) return Complex.sub(ia, ib);
        return Rational.sub(ia, ib);
    }

    public static Object mul2(Object ia, Object ib) {
        if (Value.isInteger(ia) && Value.isInteger(ib)) return IntegerMath.genericMul(ia, ib);
        if (ia instanceof Double || ib instanceof Double) {
            if (ia instanceof Complex || ib instanceof Complex) return Complex.mul(ia, ib);
            return vmToReal(ia) * vmToReal(ib);
        }
        if (ia instanceof Complex || ib instanceof Complex) return Complex.mul(ia, ib);
        return Rational.mul(ia, ib);
    }

    public static Object div2(SourcePos pos, Object ia, Object ib) {
        if (ia instanceof Long && ib instanceof Long) {
            if ((long)(Long)ib == 0) throw new SchemeError(pos, "/: Division by zero");
            return Rational.div(ia, ib);
        }
        if (ia instanceof Double || ib instanceof Double) {
            if (ia instanceof Complex || ib instanceof Complex) return Complex.div(ia, ib);
            double dib = vmToReal(ib);
            if (dib == 0.0) throw new SchemeError(pos, "/: Division by ~s", dib);
            return vmToReal(ia) / dib;
        }
        if (ia instanceof Complex || ib instanceof Complex) return Complex.div(ia, ib);
        return Rational.div(ia, ib);
    }

    public static Object negate(Object ia) {
        if (ia instanceof Long) return IntegerMath.negate((long)(Long)ia);
        if (Value.isBigInteger(ia)) return IntegerMath.genericNegate(ia);
        if (ia instanceof Double) return -(double)(Double)ia;
        if (ia instanceof Complex) return Complex.negate(ia);
        return Rational.sub(0L, ia);
    }

    // =, <, >, <=, >= on two numbers that are not both fixnums.
    public static boolean compare2(Opcode op, SourcePos pos, Object ia, Object ib) {
        if (op == Opcode.NUM_EQ) {
            if (Value.isInteger(ia) && Value.isInteger(ib)) return IntegerMath.genericEquals(ia, ib);
            if (ia instanceof Double && ib instanceof Double) return (double)(Double)ia == (double)(Double)ib;
            if (ia instanceof Complex || ib instanceof Complex) return Complex.numericEquals(ia, ib);
            return Primitive.mixedNumericEquals(ia, ib);
        }
        if (Value.isInteger(ia) && Value.isInteger(ib)) {
            int c = IntegerMath.compare(ia, ib);
            switch (op) {
                case NUM_LT: return c < 0;
                case NUM_GT: return c > 0;
                case NUM_LTE: return c <= 0;
                default: return c >= 0;
            }
        }
        if (ia instanceof Complex || ib instanceof Complex)
            throw new SchemeError(pos, opcodeErrorName(op) + ": complex numbers are not ordered");
        switch (op) {
            case NUM_LT: return Primitive.numLess(ia, ib);
            case NUM_GT: return Primitive.numGreater(ia, ib);
            case NUM_LTE: return Primitive.numLessEq(ia, ib);
            default: return Primitive.numGreaterEq(ia, ib);
        }
    }

    // The arguments of (apply f a ... list) from its rest argument.
    static List<Object> flattenApplyArgs(Instruction instruction, Object restObj) {
        List<Object> args = new ArrayList<>();
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
        return args;
    }

    // The value stack of a continuation, restored by SETCC. Sharing the
    // ReturnAddress entries is safe: they are never modified. A full
    // continuation (act null) holds the whole stack. An escape continuation
    // holds the stack segment of the nested activation act it was captured
    // in and can be invoked while act is alive (scheme.jit.Activation).
    // The code of a continuation procedure: its frame's parent holds the
    // Continuation.
    static final CodeList CONTINUATION_CODE = new CodeList();
    static {
        CONTINUATION_CODE.add(new Instruction(Opcode.ARGMV));
        CONTINUATION_CODE.add(new Instruction(Opcode.LVAR, 1, 0));
        CONTINUATION_CODE.add(new Instruction(Opcode.SETCC));
        CONTINUATION_CODE.add(new Instruction(Opcode.LVAR, 0, 0));
        CONTINUATION_CODE.add(new Instruction(Opcode.RETURN));
        JitBuiltins.attach(CONTINUATION_CODE, new JitBuiltins.ContinuationCode());
    }

    static Lambda continuationProcedure(Continuation k) {
        // Opt B: env frame must be Object[]
        return new Lambda(new Object[] { Value.NIL, k }, CONTINUATION_CODE);
    }

    // The continuation of the current stack as a procedure (CC).
    private static Lambda captureContinuation(Object[] stack, int sp) {
        return continuationProcedure(new Continuation(stack, sp));
    }

    // An escape continuation of the nested activation a (CC/ECC). The
    // activation keeps it (weakly) to turn it into a full continuation if
    // the activation is unwound into the root (rebuild).
    private static Lambda captureEscape(Activation a, Object[] stack, int sp) {
        return continuationProcedure(escape(a, new Continuation(stack, a.base + 1, sp, a)));
    }

    static Continuation escape(Activation a, Continuation k) {
        if (Jit.stats) Jit.statEscapes++;
        ArrayList<Object> escapes = a.escapes;
        if (escapes == null) a.escapes = escapes = new ArrayList<>();
        if (escapes.size() >= 64 && Integer.bitCount(escapes.size()) == 1)
            escapes.removeIf(r -> ((java.lang.ref.WeakReference<?>) r).get() == null);
        escapes.add(new java.lang.ref.WeakReference<>(k));
        return k;
    }

    // SETCC of a continuation that belongs to another activation than a.
    static RuntimeException continuationJump(Continuation k, Activation a, Lambda fn, int ip, Object env) {
        if (Jit.stats) Jit.statJumps++;
        if (k.act == null) return new ContinuationJump(k, a.nearestRoot(), fn, ip, env);
        if (!k.act.alive)
            return new SchemeError((SourcePos) null,
                "continuation invoked outside of its extent: it was captured as an escape "
                + "continuation across compiled code (scm.jit=off disables the JIT)");
        return new ContinuationJump(k, k.act, fn, ip, env);
    }

    // CC in a nested activation: unwinds to the root activation, which
    // rebuilds the stack and executes the CC at ip again.
    private static FrameCapture captureRequest(Activation a, Lambda fn, int ip, Object env, int nargs,
                                               Object[] stack, int sp) {
        if (Jit.stats) Jit.statCaptures++;
        FrameCapture fc = new FrameCapture(FrameCapture.CAPTURE, fn, ip, env, nargs);
        fc.add(Arrays.copyOfRange(stack, a.base + 1, sp), a);
        return fc;
    }

    // The escape continuations of the unwound activation a become full
    // continuations: the stack below a's segment (stack[0..sp]) is what it
    // was when they were captured, the callers being suspended since.
    private static void promoteEscapes(Activation a, Object[] stack, int sp) {
        if (a.escapes == null) return;
        for (Object r : a.escapes) {
            Continuation k = (Continuation) ((java.lang.ref.WeakReference<?>) r).get();
            if (k == null || k.act != a) continue;
            Object[] full = new Object[sp + k.stack.length];
            System.arraycopy(stack, 0, full, 0, sp);
            System.arraycopy(k.stack, 0, full, sp, k.stack.length);
            k.stack = full;
            k.act = null;
        }
        a.escapes = null;
    }

    // A compiled lambda called from the interpreter with the argcount
    // values at stack[sp..] (popped by the caller). retIp >= 0 for a
    // non-tail call: its return address, should the callee be unwound.
    private Object callJit(Lambda lam, Object[] stack, int sp, int argcount, int depth,
                           int retIp, Lambda fn, Object env) {
        Object[] frame = new Object[argcount + 1];
        for (int i = 0; i < argcount; i++) {
            frame[i + 1] = stack[sp + i];
            stack[sp + i] = null;
        }
        this.sp = sp;
        try {
            Object r = lam.cl.jit.call(this, lam, frame, depth + 1);
            return r instanceof TailCall ? Rt.trampoline(this, r, depth) : r;
        } catch (FrameCapture fc) {
            if (retIp >= 0) fc.add(new Object[] { new ReturnAddress(retIp, fn, env) }, null);
            throw fc;
        }
    }

    public static Object primaryValue(Object value) {
        if (Value.isValues(value)) {
            Object[] vals = Value.asValues(value).values;
            if (vals.length == 0) return value; // empty values = unspecified, pass through
            return vals[0];
        }
        return value;
    }

    private List<SchemeCallFrame> extractCallStack() {
        List<SchemeCallFrame> frames = new ArrayList<>();
        SourcePos currentPos = (fn != null && ip > 0 && ip - 1 < fn.codeArr.length)
            ? fn.codeArr[ip - 1].pos : null;
        frames.add(new SchemeCallFrame(fn != null ? fn.name : null, currentPos));
        for (int i = sp - 1; i >= 0; i--) {
            if (stackArr[i] instanceof ReturnAddress) {
                ReturnAddress addr = (ReturnAddress) stackArr[i];
                SourcePos callPos = (addr.ip > 0 && addr.ip - 1 < addr.fn.codeArr.length)
                    ? addr.fn.codeArr[addr.ip - 1].pos : null;
                frames.add(new SchemeCallFrame(addr.fn.name, callPos));
            }
        }
        return frames;
    }

    // "wrong argument type" for a ClassCastException in fn's instruction
    // before ip (no opcode changes ip or fn before it can fail a cast).
    public static SchemeError castError(Lambda fn, int ip, ClassCastException cce) {
        Instruction failed = fn != null && ip > 0 && ip <= fn.codeArr.length ? fn.codeArr[ip - 1] : null;
        String name = "VM";
        if (failed != null) {
            name = failed.opcode == Opcode.CXR ? (String) failed.arg2
                 : opcodeErrorName(failed.opcode);
            if (name == null) name = failed.opcode + " instruction";
        }
        return wrongArgumentTypeError(failed != null ? failed.pos : null, name, cce);
    }

    // The current activation of the interpreter loop (or of a JitBuiltins
    // escape) and the thread it runs for.
    Activation act;
    public SchemeThread thread;

    int sp() { return sp; }

    public Object execute(Lambda func) {
        VM savedCurrent = VM.current.get();
        VM.current.set(this);
        Activation savedAct = act;
        try {
            if (SchemeThread.currentThread.get() == null) {
                SchemeThread primordial = new SchemeThread(null, modules);
                primordial.name = Value.intern("primordial");
                primordial.state = SchemeThread.State.STARTED;
                SchemeThread.currentThread.set(primordial);
            }
            thread = SchemeThread.currentThread.get();
            int savedSp = sp;
            Object savedWinders = winders;
            Object savedExceptionHandlers = exceptionHandlers;
            Activation a = new Activation(savedAct, sp, 0, true);
            act = a;
            push(new ReturnAddress(func.code.size(), func, env));
            try {
                return run(a, func, this.env, 0, sp, savedWinders, savedExceptionHandlers);
            } finally {
                a.alive = false;
            }
        } finally {
            act = savedAct;
            VM.current.set(savedCurrent);
        }
    }

    // A lambda called from compiled code (or Rt), run by a nested
    // activation of the interpreter loop above the current stack.
    public Object executeNested(Lambda lam, Object[] frame, int depth) {
        CodeList cl = lam.cl;
        if (Jit.stats) { Jit.statNested++; Jit.countNested(cl); }
        if (cl.calls++ == Jit.threshold) Jit.compile(cl);
        Activation parent = act;
        Activation a = new Activation(parent, sp, depth, false);
        act = a;
        int n = frame.length - 1;
        Instruction[] code = lam.codeArr;
        int sp = this.sp;
        Object[] stack = ensureStack(stackArr, sp + n + 1 + code.length);
        stack[sp++] = new ReturnAddress(code.length, lam, lam.env);
        System.arraycopy(frame, 1, stack, sp, n);
        sp += n;
        try {
            return run(a, lam, lam.env, n, sp, null, null);
        } finally {
            a.alive = false;
            act = parent;
        }
    }

    // The interpreter loop of activation a, starting fn at instruction 0
    // with the stack up to sp. savedWinders and savedExceptionHandlers are
    // the root's, restored when an error leaves it.
    @SuppressWarnings("unchecked")
    private Object run(Activation act, Lambda fn, Object env, int nargs, int sp,
                       Object savedWinders, Object savedExceptionHandlers) {
        final int depth = act.depth;
        Instruction[] code = fn.codeArr;
        int ip = 0;
        Object[] stack = ensureStack(stackArr, sp + code.length);
        for (;;) {
        RuntimeException pending;
        try {
        while (ip < code.length) {
            Instruction instruction = code[ip++];
            switch (instruction.opcode) {
                case LVAR:
                    stack[sp] = getenv(env, instruction.i1, instruction.i2); sp++;
                    break;

                case LSET:
                    setenv(env, instruction.i1,
                           instruction.i2,
                           primaryValue(stack[sp - 1]));
                    break;

                case GVAR: {
                    Cell cell = globalCell(instruction, instruction.arg1, (String) instruction.arg2);
                    stack[sp++] = cell.value;
                    break;
                }

                case GSET: {
                    Object value = primaryValue(stack[sp - 1]);
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
                    globalSet(instruction, value);
                    break;
                }

                case POP:
                    stack[--sp] = null;
                    break;

                case CONST:
                    stack[sp++] = instruction.arg1;
                    break;

                case JUMP:
                    if (instruction.i1 < ip) stack = ensureStack(stack, sp + code.length - instruction.i1);
                    ip = instruction.i1;
                    break;

                case FJUMP:
                    if (stack[--sp] == Value.F) {
                        if (instruction.i1 < ip) stack = ensureStack(stack, sp + code.length - instruction.i1);
                        ip = instruction.i1;
                    }
                    break;

                case TJUMP:
                    if (stack[--sp] != Value.F) {
                        if (instruction.i1 < ip) stack = ensureStack(stack, sp + code.length - instruction.i1);
                        ip = instruction.i1;
                    }
                    break;

                case SAVE:
                    stack[sp++] = new ReturnAddress(instruction.i1, fn, env);
                    break;

                case RETURN: {
                    ReturnAddress address = (ReturnAddress) stack[sp - 2];
                    fn = address.fn;
                    code = fn.codeArr;
                    env = address.env;
                    ip = address.ip;
                    stack[sp - 2] = stack[sp - 1];
                    stack[--sp] = null;
                    stack = ensureStack(stack, sp + code.length - ip);
                    break;
                }

                case GCALLJ: {
                    Cell cell = globalCell(instruction, instruction.arg3, (String) instruction.arg2);
                    stack[sp++] = cell.value;
                }
                // fall through: call the global like CALLJ

                case CALLJ: {
                    SchemeThread ct = thread;
                    if (ct != null && ct.terminated)
                        throw new SchemeError("thread terminated");
                    int argcount = instruction.i1;
                    if (argcount == -1) {
                        argcount = flattened;
                        flattened = 0;
                    }
                    Object f = stack[--sp];
                    if (Value.isLambda(f)) {
                        Lambda lam = (Lambda) f;
                        CodeList cl = lam.cl;
                        if (cl.jit != null && !cl.builtin && depth < Jit.maxDepth) {
                            sp -= argcount;
                            Object result = callJit(lam, stack, sp, argcount, depth, -1, null, null);
                            stack = stackArr;
                            ReturnAddress address = (ReturnAddress) stack[sp - 1];
                            fn = address.fn;
                            code = fn.codeArr;
                            env = address.env;
                            ip = address.ip;
                            stack[sp - 1] = result;
                            stack = ensureStack(stack, sp + code.length - ip);
                            break;
                        }
                        if (cl.calls++ == Jit.threshold) Jit.compile(cl);
                        fn = lam;
                        code = fn.codeArr;
                        env = fn.env;
                        ip = 0;
                        nargs = argcount;
                        stack = ensureStack(stack, sp + code.length);
                    } else if (Value.isPrimitive(f)) {
                        sp -= argcount;
                        Object result = applyPrimitive(f, instruction.pos, stack, sp, argcount);
                        ReturnAddress address = (ReturnAddress) stack[sp - 1];
                        fn = address.fn;
                        code = fn.codeArr;
                        env = address.env;
                        ip = address.ip;
                        stack[sp - 1] = result;
                        stack = ensureStack(stack, sp + code.length - ip);
                    } else {
                        throw new SchemeError(instruction.pos, f + " is not a function, cannot apply");
                    }
                    break;
                }

                case GCALLS: {
                    Cell cell = globalCell(instruction, instruction.arg3, (String) instruction.arg2);
                    stack[sp++] = cell.value;
                }
                // fall through: call the global like CALLS

                case CALLS: {
                    SchemeThread ct = thread;
                    if (ct != null && ct.terminated)
                        throw new SchemeError("thread terminated");
                    int argcount = instruction.i1;
                    Object f = stack[--sp];
                    if (f instanceof Lambda) {
                        Lambda lam = (Lambda) f;
                        CodeList cl = lam.cl;
                        if (cl.jit != null && !cl.builtin && depth < Jit.maxDepth) {
                            sp -= argcount;
                            Object result = callJit(lam, stack, sp, argcount, depth, ip, fn, env);
                            stack = stackArr;
                            stack[sp++] = result;
                            break;
                        }
                        if (cl.calls++ == Jit.threshold) Jit.compile(cl);
                        // the return address goes under the arguments,
                        // where SAVE would have put it
                        sp++;
                        int base = sp - 1 - argcount;
                        for (int i = sp - 1; i > base; i--) stack[i] = stack[i - 1];
                        stack[base] = new ReturnAddress(ip, fn, env);
                        fn = lam;
                        code = fn.codeArr;
                        env = fn.env;
                        ip = 0;
                        nargs = argcount;
                        stack = ensureStack(stack, sp + code.length);
                    } else if (Value.isPrimitive(f)) {
                        sp -= argcount;
                        stack[sp] = applyPrimitive(f, instruction.pos, stack, sp, argcount); sp++;
                    } else {
                        throw new SchemeError(instruction.pos, f + " is not a function, cannot apply");
                    }
                    break;
                }

                case ARGS: {
                    if (nargs != instruction.i1)
                        throw arityError(fn, instruction, nargs, "");
                    Object[] frame = new Object[nargs + 1];
                    for (int i = nargs; i >= 1; i--) { frame[i] = stack[--sp]; stack[sp] = null; }
                    frame[0] = env;
                    env = frame;
                    break;
                }

                case EXTEND: {
                    int n = instruction.i1;
                    Object[] frame = new Object[n + 1];
                    for (int i = n; i >= 1; i--) { frame[i] = stack[--sp]; stack[sp] = null; }
                    frame[0] = env;
                    env = frame;
                    break;
                }

                case ARGSDOT: {
                    int fixedArgs = instruction.i1;
                    if (nargs < fixedArgs)
                        throw arityError(fn, instruction, nargs, " or more");
                    // Opt B: build Object[] frame; rest list remains a Pair chain (Scheme list)
                    Object rest = Value.NIL;
                    for (int i = 0; i < nargs - fixedArgs; i++) {
                        rest = new Pair(stack[--sp], rest);
                        stack[sp] = null;
                    }
                    Object[] frame = new Object[fixedArgs + 2];
                    frame[fixedArgs + 1] = rest;
                    for (int i = fixedArgs; i >= 1; i--) { frame[i] = stack[--sp]; stack[sp] = null; }
                    frame[0] = env;
                    env = frame;
                    break;
                }

                case ARGMV: {
                    // Opt B: build Object[] frame
                    if (nargs == 1) {
                        env = new Object[] { env, stack[--sp] };
                        stack[sp] = null;
                    } else {
                        Values mv = new Values();
                        mv.values = new Object[nargs];
                        for (int i = nargs - 1; i >= 0; i--) {
                            mv.values[i] = stack[--sp];
                            stack[sp] = null;
                        }
                        env = new Object[] { env, mv };
                    }
                    break;
                }

                case FN: {
                    Pair fn_pair = Value.asPair(instruction.arg1);
                    List<Instruction> fn_instructions = (List<Instruction>) fn_pair.sixth();
                    Lambda new_lambda = new Lambda(env, fn_instructions);
                    if (fn_pair.length() > 6) new_lambda.doc = fn_pair.eight().toString();
                    stack[sp++] = new_lambda;
                    break;
                }

                case SETCC: {
                    Continuation k = (Continuation) stack[sp - 1];
                    if (k.act == null ? !act.root : k.act != act)
                        throw continuationJump(k, act, fn, ip, env);
                    int base = k.act == null ? 0 : act.base + 1;
                    sp = base + k.stack.length;
                    stack = ensureStack(stack, sp + code.length - ip);
                    System.arraycopy(k.stack, 0, stack, base, k.stack.length);
                    break;
                }

                case CC:
                    if (!act.root) throw captureRequest(act, fn, ip - 1, env, nargs, stack, sp);
                    stack[sp] = captureContinuation(stack, sp); sp++;
                    break;

                case ECC:
                    stack[sp] = act.root ? captureContinuation(stack, sp) : captureEscape(act, stack, sp);
                    sp++;
                    break;

                case FLATTEN_APPLY: {
                    List<Object> args = flattenApplyArgs(instruction, getenv(env, instruction.i1, instruction.i2));
                    flattened = args.size();
                    stack = ensureStack(stack, sp + args.size() + code.length - ip);
                    for (int i = 0; i < args.size(); i++) {
                        stack[sp++] = args.get(i);
                    }
                    break;
                }

                case FLATTEN_MULTVALS: {
                    Object val = stack[--sp];
                    if (Value.isValues(val)) {
                        Object[] values = Value.asValues(val).values;
                        flattened = values.length;
                        stack = ensureStack(stack, sp + values.length + code.length - ip);
                        for (int i = 0; i < values.length; i++) {
                            stack[sp++] = values[i];
                        }
                    } else {
                        flattened = 1;
                        stack[sp++] = val;
                    }
                    break;
                }

                case HANDLER_RETURNED:
                    throw new SchemeError((SourcePos) null, new ErrorObject(
                        "raise: exception handler returned", new Object[0]));

                case POPENV:
                    env = ((Object[]) env)[0];
                    break;

                case TJUMP_KEEP:
                    if (stack[sp - 1] != Value.F) {
                        if (instruction.i1 < ip) stack = ensureStack(stack, sp + code.length - instruction.i1);
                        ip = instruction.i1;
                    } else {
                        stack[--sp] = null;
                    }
                    break;

                case LOOP: {
                    SchemeThread ct = thread;
                    if (ct != null && ct.terminated)
                        throw new SchemeError("thread terminated");
                    env = loopFrame(env, instruction.i2, stack, sp, instruction.i1);
                    sp -= instruction.i1;
                    ip = instruction.i3;
                    stack = ensureStack(stack, sp + code.length - ip);
                    break;
                }

                case LVAR_CAR:
                    stack[sp] = Value.asPair(getenv(env, instruction.i1, instruction.i2)).car; sp++;
                    break;

                case LVAR_CDR:
                    stack[sp] = Value.asPair(getenv(env, instruction.i1, instruction.i2)).cdr; sp++;
                    break;

                case LVAR_VREF: {
                    Object[] vec = Value.asVector(getenv(env, instruction.i1, instruction.i2));
                    int i = instruction.i3;
                    if (i >= vec.length)
                        throw new SchemeError(instruction.pos, "vector-ref: index out of range: ~a", (long) i);
                    stack[sp++] = vec[i];
                    break;
                }

                case LVAR_NULL_FJUMP:
                    if (getenv(env, instruction.i1, instruction.i2) != Value.NIL) {
                        if (instruction.i3 < ip) stack = ensureStack(stack, sp + code.length - instruction.i3);
                        ip = instruction.i3;
                    }
                    break;

                case LVAR_PAIR_FJUMP:
                    if (!Value.isPair(getenv(env, instruction.i1, instruction.i2))) {
                        if (instruction.i3 < ip) stack = ensureStack(stack, sp + code.length - instruction.i3);
                        ip = instruction.i3;
                    }
                    break;

                case CONST_EQ_FJUMP:
                    if (!PrimitiveEqP.eq(stack[--sp], instruction.arg1)) {
                        if (instruction.i2 < ip) stack = ensureStack(stack, sp + code.length - instruction.i2);
                        ip = instruction.i2;
                    }
                    break;

                case CAR:
                    stack[sp - 1] = Value.asPair(stack[sp - 1]).car;
                    break;

                case CDR:
                    stack[sp - 1] = Value.asPair(stack[sp - 1]).cdr;
                    break;

                case CXR: {
                    Object v = stack[sp - 1];
                    for (int p = instruction.i1; p != 1; p >>>= 1)
                        v = (p & 1) != 0 ? Value.asPair(v).cdr : Value.asPair(v).car;
                    stack[sp - 1] = v;
                    break;
                }

                case LIST: {
                    Object lst = Value.NIL;
                    for (int i = instruction.i1; i > 0; i--) {
                        lst = new Pair(stack[--sp], lst);
                        stack[sp] = null;
                    }
                    stack[sp++] = lst;
                    break;
                }

                case CONS: {
                    Object icdr = stack[--sp];
                    stack[sp - 1] = new Pair(stack[sp - 1], icdr);
                    break;
                }

                case IS_NULL:
                    stack[sp - 1] = stack[sp - 1] == Value.NIL ? Value.T : Value.F;
                    break;

                case IS_PAIR: {
                    Object ipv = stack[--sp];
                    stack[sp++] = Value.isPair(ipv) ? Value.T : Value.F;
                    break;
                }

                case NOT:
                    stack[sp - 1] = stack[sp - 1].equals(Value.F) ? Value.T : Value.F;
                    break;

                case LVAR_ADD_IMM: {
                    long packed = (long)(Long) instruction.arg1;
                    Object val = getenv(env, (int)(packed >> 16), (int)(packed & 0xFFFF));
                    long imm = (long)(Long) instruction.arg2;
                    if (val instanceof Long) {
                        long a = (Long) val, r = a + imm;
                        if (((a ^ r) & (imm ^ r)) >= 0) { stack[sp++] = r; break; }
                    }
                    stack[sp] = add2(val, imm); sp++;
                    break;
                }

                case LVAR_SUB_IMM: {
                    long packed = (long)(Long) instruction.arg1;
                    Object val = getenv(env, (int)(packed >> 16), (int)(packed & 0xFFFF));
                    long imm = (long)(Long) instruction.arg2;
                    if (val instanceof Long) {
                        long a = (Long) val, r = a - imm;
                        if (((a ^ imm) & (a ^ r)) >= 0) { stack[sp++] = r; break; }
                    }
                    stack[sp] = sub2(val, imm); sp++;
                    break;
                }

                case ADD: {
                    int n = instruction.i1;
                    if (n == 2) {
                        Object ib = stack[--sp], ia = stack[--sp];
                        if (ia instanceof Long && ib instanceof Long) {
                            long a = (Long) ia, b = (Long) ib, r = a + b;
                            if (((a ^ r) & (b ^ r)) >= 0) { stack[sp++] = r; break; }
                        }
                        stack[sp] = add2(ia, ib); sp++;
                        break;
                    }
                    sp -= n;
                    stack[sp] = applyIntrinsic(S_ADD, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case SUB: {
                    int n = instruction.i1;
                    if (n == 2) {
                        Object ib = stack[--sp], ia = stack[--sp];
                        if (ia instanceof Long && ib instanceof Long) {
                            long a = (Long) ia, b = (Long) ib, r = a - b;
                            if (((a ^ b) & (a ^ r)) >= 0) { stack[sp++] = r; break; }
                        }
                        stack[sp] = sub2(ia, ib); sp++;
                        break;
                    }
                    if (n == 1) {
                        Object ia = stack[--sp];
                        stack[sp] = negate(ia); sp++;
                        break;
                    }
                    sp -= n;
                    stack[sp] = applyIntrinsic(S_SUB, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case MUL: {
                    int n = instruction.i1;
                    if (n == 2) {
                        Object ib = stack[--sp], ia = stack[--sp];
                        if (ia instanceof Long && ib instanceof Long) {
                            long a = (Long) ia, b = (Long) ib, r = a * b, high = Math.multiplyHigh(a, b);
                            if ((high == 0 && r >= 0) || (high == -1 && r < 0)) { stack[sp++] = r; break; }
                        }
                        stack[sp] = mul2(ia, ib); sp++;
                        break;
                    }
                    sp -= n;
                    stack[sp] = applyIntrinsic(S_MUL, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case DIV: {
                    int n = instruction.i1;
                    if (n == 2) {
                        Object ib = stack[--sp], ia = stack[--sp];
                        stack[sp] = div2(instruction.pos, ia, ib); sp++;
                        break;
                    }
                    sp -= n;
                    stack[sp] = applyIntrinsic(S_DIV, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case NUM_EQ: {
                    int n = instruction.i1;
                    if (n == 2) {
                        Object ib = stack[--sp], ia = stack[--sp];
                        boolean r = ia instanceof Long && ib instanceof Long
                            ? (long)(Long)ia == (long)(Long)ib
                            : compare2(Opcode.NUM_EQ, instruction.pos, ia, ib);
                        stack[sp] = r ? Value.T : Value.F; sp++;
                        break;
                    }
                    sp -= n;
                    stack[sp] = applyIntrinsic(S_NUM_EQ, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case NUM_LT: {
                    int n = instruction.i1;
                    if (n == 2) {
                        Object ib = stack[--sp], ia = stack[--sp];
                        boolean r = ia instanceof Long && ib instanceof Long
                            ? (long)(Long)ia < (long)(Long)ib
                            : compare2(Opcode.NUM_LT, instruction.pos, ia, ib);
                        stack[sp] = r ? Value.T : Value.F; sp++;
                        break;
                    }
                    sp -= n;
                    stack[sp] = applyIntrinsic(S_NUM_LT, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case NUM_GT: {
                    int n = instruction.i1;
                    if (n == 2) {
                        Object ib = stack[--sp], ia = stack[--sp];
                        boolean r = ia instanceof Long && ib instanceof Long
                            ? (long)(Long)ia > (long)(Long)ib
                            : compare2(Opcode.NUM_GT, instruction.pos, ia, ib);
                        stack[sp] = r ? Value.T : Value.F; sp++;
                        break;
                    }
                    sp -= n;
                    stack[sp] = applyIntrinsic(S_NUM_GT, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case NUM_LTE: {
                    int n = instruction.i1;
                    if (n == 2) {
                        Object ib = stack[--sp], ia = stack[--sp];
                        boolean r = ia instanceof Long && ib instanceof Long
                            ? (long)(Long)ia <= (long)(Long)ib
                            : compare2(Opcode.NUM_LTE, instruction.pos, ia, ib);
                        stack[sp] = r ? Value.T : Value.F; sp++;
                        break;
                    }
                    sp -= n;
                    stack[sp] = applyIntrinsic(S_NUM_LTE, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case NUM_GTE: {
                    int n = instruction.i1;
                    if (n == 2) {
                        Object ib = stack[--sp], ia = stack[--sp];
                        boolean r = ia instanceof Long && ib instanceof Long
                            ? (long)(Long)ia >= (long)(Long)ib
                            : compare2(Opcode.NUM_GTE, instruction.pos, ia, ib);
                        stack[sp] = r ? Value.T : Value.F; sp++;
                        break;
                    }
                    sp -= n;
                    stack[sp] = applyIntrinsic(S_NUM_GTE, instruction.pos, stack, sp, n); sp++;
                    break;
                }

                case EQ_P: {
                    Object ib = stack[--sp], ia = stack[--sp];
                    stack[sp] = PrimitiveEqP.eq(ia, ib) ? Value.T : Value.F; sp++;
                    break;
                }

                case EQV_P: {
                    Object ib = stack[--sp], ia = stack[--sp];
                    stack[sp] = PrimitiveEqvP.eqv(ia, ib) ? Value.T : Value.F; sp++;
                    break;
                }

                case VECTOR_REF: {
                    Object idx = stack[--sp];
                    Object[] vec = Value.asVector(stack[--sp]);
                    int i = IntegerMath.toInt(idx);
                    if (i < 0 || i >= vec.length)
                        throw new SchemeError(instruction.pos, "vector-ref: index out of range: ~a", idx);
                    stack[sp++] = vec[i];
                    break;
                }

                case VECTOR_SET: {
                    Object val = stack[--sp];
                    Object idx = stack[--sp];
                    Object[] vec = Value.asVector(stack[--sp]);
                    int i = IntegerMath.toInt(idx);
                    if (i < 0 || i >= vec.length)
                        throw new SchemeError(instruction.pos, "vector-set!: index out of range: ~a", idx);
                    vec[i] = val;
                    stack[sp++] = new Values();
                    break;
                }

                default:
                    throw new SchemeError(instruction.pos,
                                          "Unknown opcode " + instruction.opcode);
            }
        }
        break;
        } catch (SchemeError e) {
            pending = e;
        } catch (ClassCastException cce) {
            pending = castError(fn, ip, cce);
        } catch (FrameCapture fc) {
            if (!act.root) {
                if (fc.last != act) fc.add(Arrays.copyOfRange(stackArr, act.base + 1, sp), act);
                leave(act, sp);
                throw fc;
            }
            // rebuild the unwound frames on the root's stack
            stack = stackArr;
            for (int s = fc.segments.size() - 1; s >= 0; s--) {
                Object[] seg = fc.segments.get(s);
                Activation owner = fc.owners.get(s);
                if (owner != null) promoteEscapes(owner, stack, sp);
                stack = ensureStack(stack, sp + seg.length);
                System.arraycopy(seg, 0, stack, sp, seg.length);
                sp += seg.length;
            }
            fn = fc.fn; code = fn.codeArr; ip = fc.ip; env = fc.env; nargs = fc.nargs;
            stack = ensureStack(stack, sp + code.length - ip);
            if (fc.cause == FrameCapture.CAPTURE) continue;
            pending = fc.cause instanceof ClassCastException
                ? castError(fn, ip, (ClassCastException) fc.cause)
                : (RuntimeException) fc.cause;
        } catch (ContinuationJump j) {
            if (j.target != act) {
                leave(act, sp);
                throw j;
            }
            Continuation k = (Continuation) j.continuation;
            int base = k.act == null ? 0 : act.base + 1;
            sp = base + k.stack.length;
            stack = ensureStack(stackArr, sp);
            System.arraycopy(k.stack, 0, stack, base, k.stack.length);
            fn = j.fn; code = fn.codeArr; ip = j.ip; env = j.env;
            stack = ensureStack(stack, sp + code.length - ip);
            continue;
        }
        // an error at fn/ip: the innermost exception handler is called on
        // top of the stack; with none, it leaves the root (with every
        // frame in its call stack: a nested activation unwinds to the root)
        SchemeError e = pending instanceof SchemeError ? (SchemeError) pending
            : new SchemeError((SourcePos) null, "internal error: " + pending);
        this.fn = fn; this.ip = ip; this.env = env; this.sp = sp;
        if (exceptionHandlers != Value.NIL) {
            if (e.schemeCallStack == null)
                e.schemeCallStack = extractCallStack();
            Object condition = e.errorObject != null ? e.errorObject
                : new ErrorObject(e.getMessage(), new Object[0]);
            this.nargs = nargs;
            setupRaiseCall(condition);
            fn = this.fn; code = fn.codeArr; ip = this.ip; env = this.env;
            sp = this.sp; nargs = this.nargs;
            stack = ensureStack(stackArr, sp + code.length - ip);
            continue;
        }
        if (!act.root) {
            if (Jit.stats) Jit.statErrors++;
            FrameCapture fc = new FrameCapture(e, fn, ip, env, nargs);
            fc.add(Arrays.copyOfRange(stackArr, act.base + 1, sp), act);
            leave(act, sp);
            throw fc;
        }
        if (e.schemeCallStack == null)
            e.schemeCallStack = extractCallStack();
        this.sp = act.base;
        winders = savedWinders;
        exceptionHandlers = savedExceptionHandlers;
        throw e;
        }
        if (act.root) { this.fn = fn; this.ip = ip; this.env = env; }
        Object result = stack[--sp];
        stack[sp] = null;
        this.sp = sp;
        return result;
    }

    // Clears the stack of activation a, left by an exception.
    private void leave(Activation a, int sp) {
        if (sp > a.base) Arrays.fill(stackArr, a.base, Math.min(sp, stackArr.length), null);
        this.sp = a.base;
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
