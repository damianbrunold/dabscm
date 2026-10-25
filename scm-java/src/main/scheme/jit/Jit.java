package scheme.jit;

import java.util.ArrayList;
import java.util.IdentityHashMap;
import java.util.List;

import scheme.*;

import static scheme.jit.ClassWriter.*;

// Compiles the code of a lambda to a JVM class once the interpreter has
// called it Jit.threshold times (CodeList.calls). The JVM method keeps the
// lambda's environment as the interpreter's Object[] frames and its
// operand stack in local variables (one per stack slot, whose depth is
// static: analyze), so that compiled and interpreted code share closures
// and a compiled frame can be turned into the interpreter's frame
// (Rt.unwind). Code the translation does not support stays interpreted.
//
// System properties: scm.jit=off disables it, scm.jit.threshold (calls
// before compiling, 0 compiles on the first call), scm.jit.debug=true
// reports rejected code.
public final class Jit {
    private Jit() {}

    public static final boolean enabled = !"off".equals(System.getProperty("scm.jit"));
    public static final int threshold = enabled ? Integer.getInteger("scm.jit.threshold", 1000) : -1;
    // compiled calls beyond maxDepth run in the interpreter; tail calls
    // beyond tailDepth are returned to the nearest non-tail caller
    public static final int maxDepth = Integer.getInteger("scm.jit.maxDepth", 400);
    public static final int tailDepth = Integer.getInteger("scm.jit.tailDepth", 200);
    static final boolean debug = Boolean.getBoolean("scm.jit.debug");
    // scm.jit.stats=true prints counters at exit (approximate: not synchronized)
    public static final boolean stats = Boolean.getBoolean("scm.jit.stats");
    public static long statCompiled, statRejected, statNested, statCaptures, statErrors, statJumps,
        statTailCalls, statEscapes;
    public static final java.util.Map<CodeList, long[]> nestedCounts =
        java.util.Collections.synchronizedMap(new java.util.IdentityHashMap<>());
    public static void countNested(CodeList cl) {
        nestedCounts.computeIfAbsent(cl, k -> new long[1])[0]++;
    }
    static {
        if (stats) Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            nestedCounts.entrySet().stream()
                .sorted((x, y) -> Long.compare(y.getValue()[0], x.getValue()[0])).limit(15)
                .forEach(e -> System.err.println("  nested " + e.getValue()[0] + " "
                    + (e.getKey().jitRejected ? "rejected " : e.getKey().jit != null ? "compiled " : "")
                    + "calls=" + e.getKey().calls + " " + describe(e.getKey())));
        }));
        if (stats) Runtime.getRuntime().addShutdownHook(new Thread(() -> System.err.println(
            "jit stats: compiled " + statCompiled + ", rejected " + statRejected
            + ", nested activations " + statNested + ", full captures " + statCaptures
            + ", unwound errors " + statErrors + ", escape continuations " + statEscapes
            + ", continuation jumps " + statJumps + ", trampolined tail calls " + statTailCalls)));
    }
    // C2 does not compile larger methods (HugeMethodLimit)
    private static final int MAX_CODE = 7900;

    private static int counter;
    private static final ThreadLocal<Object[]> constants = new ThreadLocal<>();

    // Compiles cl, or marks it rejected.
    public static void compile(CodeList cl) {
        if (cl.jit != null || cl.jitRejected) return;
        try {
            Translator t = new Translator(cl, false);
            JitCode jit = t.translate();
            if (jit == null && t.tooLarge) jit = new Translator(cl, true).translate();
            if (jit == null) cl.jitRejected = true;
            else cl.jit = jit;
            if (stats) { if (jit == null) statRejected++; else statCompiled++; }
            if (debug) System.err.println("jit: " + (jit == null ? "rejected " : "compiled ")
                + (jit != null ? jit.getClass().getSimpleName() + " " : "") + describe(cl));
        } catch (Throwable e) {
            cl.jitRejected = true;
            if (debug) {
                System.err.println("jit: " + e);
                e.printStackTrace();
            }
        }
    }

    private static String describe(CodeList cl) {
        Instruction[] code = cl.array();
        SourcePos pos = code.length > 0 ? code[0].pos : null;
        StringBuilder ops = new StringBuilder();
        if (cl.depths == null || stats) {
            for (Instruction i : code) {
                ops.append(' ').append(i.opcode);
                if (ops.length() > 120) break;
            }
        }
        return (pos != null ? pos.toString() : "?") + ops;
    }

    // Called by the static initializer of a generated class.
    public static Object[] takeConstants() {
        Object[] c = constants.get();
        constants.remove();
        return c;
    }

    // ---- analysis ----

    // The operand stack depth before each instruction (-1 if unreachable),
    // or null if the code cannot be compiled.
    static int[] analyze(Instruction[] code) {
        int n = code.length;
        if (n == 0) return null;
        Opcode first = code[0].opcode;
        if (first != Opcode.ARGS && first != Opcode.ARGSDOT) return null;
        int[] depth = new int[n];
        java.util.Arrays.fill(depth, -1);
        int[] work = new int[n + 1];
        int top = 0;
        depth[0] = 0;
        work[top++] = 0;
        while (top > 0) {
            int i = work[--top];
            int d = depth[i];
            Instruction ins = code[i];
            int next = d, target = -1, targetDepth = -1;
            boolean falls = true;
            switch (ins.opcode) {
                case ARGS: case ARGSDOT:
                    if (i != 0) return null;
                    break;
                case LVAR: case GVAR: case CONST: case FN:
                case LVAR_ADD_IMM: case LVAR_SUB_IMM: case LVAR_CAR: case LVAR_CDR: case LVAR_VREF:
                    next = d + 1; break;
                case LSET: case GSET: case POPENV:
                case CAR: case CDR: case NOT: case IS_NULL: case IS_PAIR: case CXR:
                    if (d < 1 && ins.opcode != Opcode.POPENV) return null;
                    break;
                case POP: case CONS: case EQ_P: case EQV_P: case VECTOR_REF:
                    next = d - 1; break;
                case VECTOR_SET:
                    next = d - 2; break;
                case ADD: case SUB: case MUL: case DIV:
                case NUM_EQ: case NUM_LT: case NUM_GT: case NUM_LTE: case NUM_GTE:
                case LIST:
                    if (ins.i1 < 0) return null;
                    next = d - ins.i1 + 1; break;
                case JUMP:
                    falls = false; target = ins.i1; targetDepth = d; break;
                case FJUMP: case TJUMP:
                    next = d - 1; target = ins.i1; targetDepth = d - 1; break;
                case TJUMP_KEEP:
                    next = d - 1; target = ins.i1; targetDepth = d; break;
                case LVAR_NULL_FJUMP: case LVAR_PAIR_FJUMP:
                    target = ins.i3; targetDepth = d; break;
                case CONST_EQ_FJUMP:
                    next = d - 1; target = ins.i2; targetDepth = d - 1; break;
                case RETURN:
                    if (d != 1) return null;
                    falls = false; break;
                case CALLS:
                    if (ins.i1 < 0) return null;
                    next = d - ins.i1; break;
                case GCALLS:
                    if (ins.i1 < 0) return null;
                    next = d - ins.i1 + 1; break;
                case CALLJ:
                    if (ins.i1 < 0 || d != ins.i1 + 1) return null;
                    falls = false; break;
                case GCALLJ:
                    if (ins.i1 < 0 || d != ins.i1) return null;
                    falls = false; break;
                case EXTEND:
                    next = d - ins.i1; break;
                case LOOP:
                    falls = false; target = ins.i3; targetDepth = d - ins.i1; break;
                default:
                    return null;
            }
            if (next < 0 || (target >= 0 && targetDepth < 0)) return null;
            if (falls) {
                if (i + 1 >= n) return null;
                if (depth[i + 1] < 0) { depth[i + 1] = next; work[top++] = i + 1; }
                else if (depth[i + 1] != next) return null;
            }
            if (target >= 0) {
                if (target >= n) return null;
                if (depth[target] < 0) { depth[target] = targetDepth; work[top++] = target; }
                else if (depth[target] != targetDepth) return null;
            }
        }
        return depth;
    }

    // Whether f is a lambda of one parameter whose code only calls the
    // parameter directly (not from a nested lambda, never passing or
    // storing it): a continuation passed to f can then only be invoked
    // while f runs, within the extent of the call/cc.
    public static boolean escapeOnly(Lambda f) {
        CodeList cl = f.cl;
        if (cl.escapeOnly == 0) cl.escapeOnly = computeEscapeOnly(f.codeArr) ? (byte) 1 : (byte) 2;
        return cl.escapeOnly == 1;
    }

    private static boolean computeEscapeOnly(Instruction[] code) {
        if (code.length == 0 || code[0].opcode != Opcode.ARGS || code[0].i1 != 1) return false;
        return scanEscape(code, 0, false);
    }

    // Data flow over code with the number of environment frames above its
    // own argument frame; the parameter's frame is that number plus
    // kOffset. In the receiver itself (not nested) the parameter may only
    // be called directly; nested code may not refer to it at all.
    private static boolean scanEscape(Instruction[] code, int kOffset, boolean nested) {
        if (code.length == 0) return true;
        int[] env = new int[code.length];
        java.util.Arrays.fill(env, -1);
        env[0] = 0;
        int[] work = new int[code.length];
        int top = 0;
        work[top++] = 0;
        while (top > 0) {
            int i = work[--top];
            int e = env[i];
            int k = e + kOffset;
            Instruction ins = code[i];
            int next = e, target = -1, targetEnv = e;
            boolean falls = true;
            switch (ins.opcode) {
                case LVAR:
                    if (ins.i1 == k && ins.i2 == 0) {
                        if (nested || i + 1 >= code.length) return false;
                        Opcode op = code[i + 1].opcode;
                        if (op != Opcode.CALLS && op != Opcode.CALLJ) return false;
                    }
                    break;
                case LSET: case LVAR_CAR: case LVAR_CDR: case LVAR_VREF: case FLATTEN_APPLY:
                    if (ins.i1 == k && ins.i2 == 0) return false;
                    break;
                case LVAR_NULL_FJUMP: case LVAR_PAIR_FJUMP:
                    if (ins.i1 == k && ins.i2 == 0) return false;
                    target = ins.i3;
                    break;
                case LVAR_ADD_IMM: case LVAR_SUB_IMM: {
                    long packed = (Long) ins.arg1;
                    if ((int) (packed >> 16) == k && (packed & 0xFFFF) == 0) return false;
                    break;
                }
                case FN: {
                    List<Instruction> body = fnCode(ins);
                    if (!scanEscape(body.toArray(new Instruction[0]), 1 + k, true)) return false;
                    break;
                }
                case EXTEND: next = e + 1; break;
                case POPENV: next = e - 1; break;
                case JUMP: falls = false; target = ins.i1; break;
                case FJUMP: case TJUMP: case TJUMP_KEEP: target = ins.i1; break;
                case CONST_EQ_FJUMP: target = ins.i2; break;
                case LOOP: falls = false; target = ins.i3; targetEnv = e - ins.i2 + 1; break;
                case RETURN: case CALLJ: case GCALLJ: falls = false; break;
                case ARGS: case ARGSDOT: if (i != 0) return false; break;
                case ARGMV: case SAVE: case CC: case ECC: case SETCC: case FLATTEN_MULTVALS:
                    if (!nested) return false;
                    break;
                default: break;
            }
            if (next < 0 || targetEnv < 0) return false;
            if (falls && i + 1 < code.length && env[i + 1] < 0) { env[i + 1] = next; work[top++] = i + 1; }
            if (target >= 0 && target < code.length && env[target] < 0) { env[target] = targetEnv; work[top++] = target; }
        }
        return true;
    }

    @SuppressWarnings("unchecked")
    private static List<Instruction> fnCode(Instruction ins) {
        return (List<Instruction>) Value.asPair(ins.arg1).sixth();
    }

    // ---- translation ----

    private static final String OBJ = "java/lang/Object", OBJD = "Ljava/lang/Object;",
        OBJA = "[Ljava/lang/Object;", INS = "scheme/Instruction", INSD = "Lscheme/Instruction;",
        VMC = "scheme/VM", LAM = "scheme/Lambda", RT = "scheme/jit/Rt", VAL = "scheme/Value",
        PAIR = "scheme/Pair", JITC = "scheme/jit/JitCode";
    private static final String CALL_DESC = "(Lscheme/VM;Lscheme/Lambda;[Ljava/lang/Object;I)Ljava/lang/Object;";

    private static final class Loader extends ClassLoader {
        Loader() { super(Jit.class.getClassLoader()); }
        Class<?> define(String name, byte[] b) { return defineClass(name, b, 0, b.length); }
    }

    private static final class Translator {
        // locals of call
        static final int VM_ = 1, SELF = 2, FRAME = 3, DEPTH = 4, ENV = 5, S0 = 6;

        final CodeList cl;
        final Instruction[] code;
        final String cls;
        final ClassWriter cw;
        ClassWriter.Code c;
        int[] depths;
        int slots;
        int tF, tLam, tJit, tFrame, tX, tIp, tExc;
        int[] label;
        boolean[] target;
        final List<Object> consts = new ArrayList<>();
        final List<String> constDescs = new ArrayList<>();
        final IdentityHashMap<Object, Integer> constIndex = new IdentityHashMap<>();

        // compact code for large lambdas: calls through Rt helpers
        final boolean compact;
        boolean tooLarge;

        Translator(CodeList cl, boolean compact) {
            this.compact = compact;
            this.cl = cl;
            this.code = cl.array();
            int n;
            synchronized (Jit.class) { n = ++counter; }
            this.cls = "scheme/jit/gen/L" + n;
            this.cw = new ClassWriter(cls, JITC);
        }

        int konst(Object v, String desc) {
            Integer k = constIndex.get(v);
            if (k != null && constDescs.get(k).equals(desc)) return k;
            consts.add(v);
            constDescs.add(desc);
            constIndex.put(v, consts.size() - 1);
            return consts.size() - 1;
        }

        void getConst(Object v, String desc) {
            int k = konst(v, desc);
            c.field(GETSTATIC, cls, "K" + k, desc);
        }

        void ins(Instruction i) { getConst(i, INSD); }

        int slot(int k) { return S0 + k; }

        // The environment of the code is kept in locals: F(k) holds the
        // frame k levels above the argument frame F(0) (EXTEND/LOOP), O(k)
        // the frame k levels above F(0)'s parent, ... (the closure's).
        int[] levels;
        int maxLevel, maxOuter, f0, o1, lvl;

        int fLocal(int k) { return f0 + k; }
        int oLocal(int k) { return o1 + k - 1; }

        // The environment level before each instruction (-1 before ARGS).
        boolean analyzeLevels() {
            int n = code.length;
            levels = new int[n];
            java.util.Arrays.fill(levels, -2);
            levels[0] = -1;
            int[] work = new int[n];
            int top = 0;
            work[top++] = 0;
            while (top > 0) {
                int i = work[--top];
                int l = levels[i];
                Instruction ins = code[i];
                int next = l, target = -1, targetLevel = l, ref = -1;
                boolean falls = true;
                switch (ins.opcode) {
                    case ARGS: case ARGSDOT: next = 0; break;
                    case EXTEND: next = l + 1; break;
                    case POPENV: next = l - 1; break;
                    case LVAR: case LSET: case LVAR_CAR: case LVAR_CDR: case LVAR_VREF: ref = ins.i1; break;
                    case LVAR_NULL_FJUMP: case LVAR_PAIR_FJUMP: ref = ins.i1; target = ins.i3; break;
                    case LVAR_ADD_IMM: case LVAR_SUB_IMM: ref = (int) ((Long) ins.arg1 >> 16); break;
                    case JUMP: falls = false; target = ins.i1; break;
                    case FJUMP: case TJUMP: case TJUMP_KEEP: target = ins.i1; break;
                    case CONST_EQ_FJUMP: target = ins.i2; break;
                    case LOOP: falls = false; target = ins.i3; targetLevel = l - ins.i2 + 1; ref = ins.i2; break;
                    case RETURN: case CALLJ: case GCALLJ: falls = false; break;
                    default: break;
                }
                if (ref > l) maxOuter = Math.max(maxOuter, ref - l);
                if (next < 0 || (target >= 0 && targetLevel < 0)) return false;
                if (next > maxLevel) maxLevel = next;
                if (falls && i + 1 < n) {
                    if (levels[i + 1] == -2) { levels[i + 1] = next; work[top++] = i + 1; }
                    else if (levels[i + 1] != next) return false;
                }
                if (target >= 0) {
                    if (levels[target] == -2) { levels[target] = targetLevel; work[top++] = target; }
                    else if (levels[target] != targetLevel) return false;
                }
            }
            return true;
        }

        // the frame frames levels up from the current environment
        void frameAt(int frames) {
            if (frames <= lvl) c.aload(fLocal(lvl - frames));
            else c.aload(oLocal(frames - lvl));
        }

        // after ARGS/ARGSDOT: F(0) and the closure's frames from ENV
        void enterFrames() {
            c.aload(ENV); c.astore(fLocal(0));
            for (int k = 1; k <= maxOuter; k++) {
                if (k == 1) { c.aload(SELF); c.field(GETFIELD, LAM, "env", OBJD); }
                else { c.aload(oLocal(k - 1)); c.iconst(0); c.op(AALOAD); }
                c.type(CHECKCAST, OBJA);
                c.astore(oLocal(k));
            }
        }

        JitCode translate() throws Exception {
            depths = analyze(code);
            if (depths == null) return null;
            cl.depths = depths;
            int max = 1;
            for (int d : depths) if (d + 1 > max) max = d + 1;
            slots = max;
            tF = S0 + slots; tLam = tF + 1; tJit = tF + 2; tFrame = tF + 3; tX = tF + 4;
            tIp = tF + 5; tExc = tF + 6;
            if (!analyzeLevels()) return null;
            f0 = tExc + 1;
            o1 = f0 + maxLevel + 1;
            target = new boolean[code.length];
            for (Instruction ins : code) {
                switch (ins.opcode) {
                    case JUMP: case FJUMP: case TJUMP: case TJUMP_KEEP: target[ins.i1] = true; break;
                    case LOOP: case LVAR_NULL_FJUMP: case LVAR_PAIR_FJUMP: target[ins.i3] = true; break;
                    case CONST_EQ_FJUMP: target[ins.i2] = true; break;
                    default: break;
                }
            }
            c = cw.code();
            label = new int[code.length];
            for (int i = 0; i < code.length; i++) label[i] = c.newLabel();
            emitCall();
            if (c.size() > MAX_CODE) {
                if (debug) {
                    java.util.TreeMap<String, Integer> h = new java.util.TreeMap<>();
                    for (Instruction x : code) h.merge(x.opcode.toString(), 1, Integer::sum);
                    System.err.println("jit: too large" + (compact ? " (compact): " : ": ") + c.size()
                        + " instructions " + code.length + " slots " + slots + " " + h);
                }
                tooLarge = true;
                return null;
            }
            cw.method(ACC_PUBLIC, "call", CALL_DESC, c);
            emitInit();
            emitClinit();
            byte[] bytes = cw.toBytes();
            Class<?> k = new Loader().define(cls.replace('/', '.'), bytes);
            constants.set(consts.toArray());
            try {
                return (JitCode) k.getDeclaredConstructor().newInstance();
            } finally {
                constants.remove();
            }
        }

        void emitInit() {
            ClassWriter.Code ic = cw.code();
            ic.aload(0);
            ic.invoke(INVOKESPECIAL, JITC, "<init>", "()V");
            ic.op(RETURN);
            cw.method(ACC_PUBLIC, "<init>", "()V", ic);
        }

        void emitClinit() {
            ClassWriter.Code ic = cw.code();
            ic.invoke(INVOKESTATIC, "scheme/jit/Jit", "takeConstants", "()" + OBJA);
            ic.astore(0);
            for (int k = 0; k < consts.size(); k++) {
                String desc = constDescs.get(k);
                cw.field(ACC_PRIVATE | ACC_STATIC | ACC_FINAL, "K" + k, desc);
                ic.aload(0);
                ic.iconst(k);
                ic.op(AALOAD);
                if (!desc.equals(OBJD)) ic.type(CHECKCAST, desc.substring(1, desc.length() - 1));
                ic.field(PUTSTATIC, cls, "K" + k, desc);
            }
            ic.op(RETURN);
            cw.method(ACC_STATIC, "<clinit>", "()V", ic);
        }

        void emitCall() {
            c.maxStack = 16;
            for (int k = 0; k < slots; k++) { c.op(ACONST_NULL); c.astore(slot(k)); }
            for (int k = 0; k <= maxLevel; k++) { c.op(ACONST_NULL); c.astore(fLocal(k)); }
            c.op(ACONST_NULL); c.astore(ENV);
            int start = c.newLabel();
            c.mark(start);
            List<int[]> ranges = new ArrayList<>();
            for (int i = 0; i < code.length; i++) {
                c.mark(label[i]);
                if (depths[i] < 0) continue;
                int from = c.newLabel();
                c.mark(from);
                if (i == 0) {
                    c.aload(VM_);
                    c.invoke(INVOKESTATIC, RT, "checkTerm", "(Lscheme/VM;)V");
                }
                lvl = levels[i];
                boolean fused = emit(i, start);
                int to = c.newLabel();
                c.mark(to);
                if (c.labelPos(to) > c.labelPos(from) && (i == 0 || canThrow(code[i].opcode)))
                    ranges.add(new int[] { from, to, i });
                if (fused) i++;
            }
            // handler stubs: the instruction index, then the common handler
            int common = c.newLabel();
            for (int[] r : ranges) {
                int stub = c.newLabel();
                c.mark(stub);
                c.iconst(r[2]);
                c.jump(GOTO, common);
                c.handler(r[0], r[1], stub, "java/lang/RuntimeException");
            }
            c.mark(common);
            c.istore(tIp);
            c.astore(tExc);
            c.aload(tExc);
            c.aload(VM_);
            c.aload(SELF);
            c.iload(tIp);
            c.aload(ENV);
            c.iconst(slots);
            c.type(ANEWARRAY, OBJ);
            for (int k = 0; k < slots; k++) {
                c.op(DUP); c.iconst(k); c.aload(slot(k)); c.op(AASTORE);
            }
            c.iload(DEPTH);
            c.invoke(INVOKESTATIC, RT, "unwind",
                     "(Ljava/lang/Throwable;Lscheme/VM;Lscheme/Lambda;IL" + OBJ + ";" + OBJA + "I)Ljava/lang/Throwable;");
            c.op(ATHROW);
        }

        // Whether the code of an instruction can throw (a fused test
        // throws as its first instruction).
        boolean canThrow(Opcode op) {
            switch (op) {
                case CONST: case POP: case JUMP: case FJUMP: case TJUMP: case TJUMP_KEEP: case RETURN:
                case LVAR: case LSET: case POPENV: case EXTEND: case FN: case CONS: case LIST:
                case IS_NULL: case IS_PAIR: case NOT: case EQ_P: case EQV_P:
                case LVAR_NULL_FJUMP: case LVAR_PAIR_FJUMP: case CONST_EQ_FJUMP:
                    return false;
                default:
                    return true;
            }
        }

        void envFrame(int frames) {
            frameAt(frames);
        }

        void getenv(int frame, int var) {
            envFrame(frame);
            c.iconst(var + 1);
            c.op(AALOAD);
        }

        void store(int k) { c.astore(slot(k)); }
        void load(int k) { c.aload(slot(k)); }

        void rt(String name, String desc) { c.invoke(INVOKESTATIC, RT, name, desc); }

        // a new Object[n] of slots from..from+n-1, with an empty index 0 if frame
        void array(int from, int n, boolean frame) {
            int off = frame ? 1 : 0;
            c.iconst(n + off);
            c.type(ANEWARRAY, OBJ);
            for (int k = 0; k < n; k++) {
                c.op(DUP); c.iconst(k + off); load(from + k); c.op(AASTORE);
            }
        }

        // Returns true if instruction i + 1 was fused into i.
        boolean emit(int i, int start) {
            Instruction ins = code[i];
            int d = depths[i];
            switch (ins.opcode) {
                case ARGS: {
                    int ok = c.newLabel();
                    c.aload(FRAME); c.op(ARRAYLENGTH); c.iconst(ins.i1 + 1);
                    c.jump(IF_ICMPEQ, ok);
                    c.aload(SELF); ins(ins); c.aload(FRAME); c.op(ARRAYLENGTH); c.iconst(1); c.op(ISUB);
                    rt("arity", "(Lscheme/Lambda;Lscheme/Instruction;I)Lscheme/SchemeError;");
                    c.op(ATHROW);
                    c.mark(ok);
                    c.aload(FRAME); c.iconst(0); c.aload(SELF); c.field(GETFIELD, LAM, "env", OBJD); c.op(AASTORE);
                    c.aload(FRAME); c.astore(ENV);
                    enterFrames();
                    return false;
                }
                case ARGSDOT:
                    c.aload(SELF); ins(ins); c.aload(FRAME);
                    rt("argsDot", "(Lscheme/Lambda;Lscheme/Instruction;" + OBJA + ")" + OBJA);
                    c.astore(ENV);
                    enterFrames();
                    return false;
                case LVAR:
                    getenv(ins.i1, ins.i2); store(d);
                    return false;
                case LSET:
                    envFrame(ins.i1); c.iconst(ins.i2 + 1); load(d - 1);
                    rt("pv", "(" + OBJD + ")" + OBJD);
                    c.op(AASTORE);
                    return false;
                case GVAR:
                    c.aload(VM_); ins(ins); rt("gvar", "(Lscheme/VM;Lscheme/Instruction;)" + OBJD); store(d);
                    return false;
                case GSET:
                    c.aload(VM_); ins(ins); load(d - 1); rt("gset", "(Lscheme/VM;Lscheme/Instruction;" + OBJD + ")V");
                    return false;
                case POP:
                    return false;
                case CONST:
                    getConst(ins.arg1, OBJD); store(d);
                    return false;
                case JUMP:
                    c.jump(GOTO, label[ins.i1]);
                    return false;
                case FJUMP: case TJUMP:
                    load(d - 1); c.field(GETSTATIC, VAL, "F", "Ljava/lang/Boolean;");
                    c.jump(ins.opcode == Opcode.FJUMP ? IF_ACMPEQ : IF_ACMPNE, label[ins.i1]);
                    return false;
                case TJUMP_KEEP:
                    load(d - 1); c.field(GETSTATIC, VAL, "F", "Ljava/lang/Boolean;");
                    c.jump(IF_ACMPNE, label[ins.i1]);
                    return false;
                case RETURN:
                    load(d - 1); c.op(ARETURN);
                    return false;
                case CALLS: emitInvoke(ins, d, false, false, start); return false;
                case GCALLS: emitInvoke(ins, d, false, true, start); return false;
                case CALLJ: emitInvoke(ins, d, true, false, start); return false;
                case GCALLJ: emitInvoke(ins, d, true, true, start); return false;
                case FN: {
                    Pair f = Value.asPair(ins.arg1);
                    String doc = f.length() > 6 ? f.eight().toString() : null;
                    c.aload(ENV);
                    getConst(fnCode(ins), "Ljava/util/List;");
                    if (doc == null) c.op(ACONST_NULL); else c.ldcString(doc);
                    rt("makeLambda", "(" + OBJD + "Ljava/util/List;Ljava/lang/String;)Lscheme/Lambda;");
                    store(d);
                    return false;
                }
                case EXTEND: {
                    int n = ins.i1;
                    c.iconst(n + 1); c.type(ANEWARRAY, OBJ);
                    c.op(DUP); c.iconst(0); c.aload(ENV); c.op(AASTORE);
                    for (int k = 1; k <= n; k++) { c.op(DUP); c.iconst(k); load(d - n + k - 1); c.op(AASTORE); }
                    c.op(DUP); c.astore(ENV);
                    c.astore(fLocal(lvl + 1));
                    return false;
                }
                case POPENV:
                    c.aload(fLocal(lvl - 1)); c.astore(ENV);
                    return false;
                case LOOP: {
                    int n = ins.i1;
                    c.aload(VM_); rt("checkTerm", "(Lscheme/VM;)V");
                    c.iconst(n + 1); c.type(ANEWARRAY, OBJ);
                    c.op(DUP); c.iconst(0);
                    frameAt(ins.i2);
                    c.op(AASTORE);
                    for (int k = 1; k <= n; k++) { c.op(DUP); c.iconst(k); load(d - n + k - 1); c.op(AASTORE); }
                    c.op(DUP); c.astore(ENV);
                    c.astore(fLocal(lvl - ins.i2 + 1));
                    c.jump(GOTO, label[ins.i3]);
                    return false;
                }
                case CAR: case CDR:
                    load(d - 1);
                    c.invoke(INVOKESTATIC, VAL, "asPair", "(" + OBJD + ")Lscheme/Pair;");
                    c.field(GETFIELD, PAIR, ins.opcode == Opcode.CAR ? "car" : "cdr", OBJD);
                    store(d - 1);
                    return false;
                case LVAR_CAR: case LVAR_CDR:
                    getenv(ins.i1, ins.i2);
                    c.invoke(INVOKESTATIC, VAL, "asPair", "(" + OBJD + ")Lscheme/Pair;");
                    c.field(GETFIELD, PAIR, ins.opcode == Opcode.LVAR_CAR ? "car" : "cdr", OBJD);
                    store(d);
                    return false;
                case CONS:
                    c.type(NEW, PAIR); c.op(DUP); load(d - 2); load(d - 1);
                    c.invoke(INVOKESPECIAL, PAIR, "<init>", "(" + OBJD + OBJD + ")V");
                    store(d - 2);
                    return false;
                case CXR:
                    load(d - 1); c.iconst(ins.i1); rt("cxr", "(" + OBJD + "I)" + OBJD); store(d - 1);
                    return false;
                case LIST: {
                    int n = ins.i1;
                    c.field(GETSTATIC, VAL, "NIL", "Lscheme/Nil;");
                    c.astore(tX);
                    for (int k = n - 1; k >= 0; k--) {
                        c.type(NEW, PAIR); c.op(DUP); load(d - n + k); c.aload(tX);
                        c.invoke(INVOKESPECIAL, PAIR, "<init>", "(" + OBJD + OBJD + ")V");
                        c.astore(tX);
                    }
                    c.aload(tX); store(d - n);
                    return false;
                }
                case VECTOR_REF:
                    load(d - 2); load(d - 1); ins(ins);
                    rt("vectorRef", "(" + OBJD + OBJD + INSD + ")" + OBJD); store(d - 2);
                    return false;
                case VECTOR_SET:
                    load(d - 3); load(d - 2); load(d - 1); ins(ins);
                    rt("vectorSet", "(" + OBJD + OBJD + OBJD + INSD + ")" + OBJD); store(d - 3);
                    return false;
                case LVAR_VREF:
                    getenv(ins.i1, ins.i2); c.iconst(ins.i3); ins(ins);
                    rt("vrefConst", "(" + OBJD + "I" + INSD + ")" + OBJD); store(d);
                    return false;
                case LVAR_ADD_IMM: case LVAR_SUB_IMM: {
                    long packed = (Long) ins.arg1;
                    getenv((int) (packed >> 16), (int) (packed & 0xFFFF));
                    c.lconst((Long) ins.arg2);
                    rt(ins.opcode == Opcode.LVAR_ADD_IMM ? "addImm" : "subImm", "(" + OBJD + "J)" + OBJD);
                    store(d);
                    return false;
                }
                case LVAR_NULL_FJUMP:
                    getenv(ins.i1, ins.i2); c.field(GETSTATIC, VAL, "NIL", "Lscheme/Nil;");
                    c.jump(IF_ACMPNE, label[ins.i3]);
                    return false;
                case LVAR_PAIR_FJUMP:
                    getenv(ins.i1, ins.i2);
                    c.invoke(INVOKESTATIC, VAL, "isPair", "(" + OBJD + ")Z");
                    c.jump(IFEQ, label[ins.i3]);
                    return false;
                case CONST_EQ_FJUMP:
                    load(d - 1); getConst(ins.arg1, OBJD);
                    c.invoke(INVOKESTATIC, "scheme/primitives/PrimitiveEqP", "eq", "(" + OBJD + OBJD + ")Z");
                    c.jump(IFEQ, label[ins.i2]);
                    return false;
                default:
                    return emitOperator(i, ins, d);
            }
        }

        // The value-producing intrinsics; a test followed by FJUMP/TJUMP
        // (not a jump target) branches on the boolean directly.
        boolean emitOperator(int i, Instruction ins, int d) {
            Instruction next = i + 1 < code.length && !target[i + 1] ? code[i + 1] : null;
            boolean branch = next != null && (next.opcode == Opcode.FJUMP || next.opcode == Opcode.TJUMP);
            String test = null;     // a boolean method when branching
            String value = null;    // else an Object method
            int arity = 2;
            boolean withIns = false;
            switch (ins.opcode) {
                case IS_NULL: arity = 1; value = "isNull"; break;
                case IS_PAIR: arity = 1; value = "isPair"; break;
                case NOT: arity = 1; value = "not"; test = "isFalse"; break;
                case EQ_P: value = "eq"; break;
                case EQV_P: value = "eqv"; break;
                case ADD: case SUB: case MUL: case DIV:
                case NUM_EQ: case NUM_LT: case NUM_GT: case NUM_LTE: case NUM_GTE: {
                    int n = ins.i1;
                    if (ins.opcode == Opcode.SUB && n == 1) { arity = 1; value = "negate"; break; }
                    if (n != 2) {
                        array(d - n, n, false); ins(ins);
                        rt("nary", "(" + OBJA + INSD + ")" + OBJD);
                        store(d - n);
                        return false;
                    }
                    switch (ins.opcode) {
                        case ADD: value = "add"; break;
                        case SUB: value = "sub"; break;
                        case MUL: value = "mul"; break;
                        case DIV: value = "div"; withIns = true; break;
                        case NUM_EQ: value = "numEq"; test = "numEqZ"; withIns = true; break;
                        case NUM_LT: value = "numLt"; test = "numLtZ"; withIns = true; break;
                        case NUM_GT: value = "numGt"; test = "numGtZ"; withIns = true; break;
                        case NUM_LTE: value = "numLte"; test = "numLteZ"; withIns = true; break;
                        default: value = "numGte"; test = "numGteZ"; withIns = true; break;
                    }
                    break;
                }
                default:
                    throw new IllegalStateException("jit: unsupported " + ins.opcode);
            }
            for (int k = arity; k >= 1; k--) load(d - k);
            String args = arity == 1 ? OBJD : OBJD + OBJD;
            if (withIns) { ins(ins); args += INSD; }
            if (branch && (test != null || ins.opcode == Opcode.IS_NULL || ins.opcode == Opcode.IS_PAIR
                           || ins.opcode == Opcode.EQ_P || ins.opcode == Opcode.EQV_P)) {
                boolean jumpIfTrue = next.opcode == Opcode.TJUMP;
                switch (ins.opcode) {
                    case IS_NULL:
                        c.field(GETSTATIC, VAL, "NIL", "Lscheme/Nil;");
                        c.jump(jumpIfTrue ? IF_ACMPEQ : IF_ACMPNE, label[next.i1]);
                        return true;
                    case IS_PAIR:
                        c.invoke(INVOKESTATIC, VAL, "isPair", "(" + OBJD + ")Z"); break;
                    case EQ_P:
                        c.invoke(INVOKESTATIC, "scheme/primitives/PrimitiveEqP", "eq", "(" + OBJD + OBJD + ")Z"); break;
                    case EQV_P:
                        c.invoke(INVOKESTATIC, "scheme/primitives/PrimitiveEqvP", "eqv", "(" + OBJD + OBJD + ")Z"); break;
                    case NOT:
                        // (not x) is true when x is false
                        rt("isFalse", "(" + OBJD + ")Z"); break;
                    default:
                        rt(test, "(" + args + ")Z"); break;
                }
                c.jump(jumpIfTrue ? IFNE : IFEQ, label[next.i1]);
                return true;
            }
            rt(value, "(" + args + ")" + OBJD);
            store(d - arity);
            return false;
        }

        // CALLS/GCALLS (non-tail) and CALLJ/GCALLJ (tail).
        void emitInvoke(Instruction ins, int d, boolean tail, boolean global, int start) {
            if (compact) { emitCompactInvoke(ins, d, tail, global, start); return; }
            int n = ins.i1;
            int argBase = global ? d - n : d - n - 1;
            array(argBase, n, true);
            c.astore(tFrame);
            if (global) {
                c.aload(VM_); ins(ins); rt("gvarCall", "(Lscheme/VM;Lscheme/Instruction;)" + OBJD);
            } else {
                load(d - 1);
            }
            c.astore(tF);
            int prim = c.newLabel(), interp = c.newLabel(), got = c.newLabel(), done = c.newLabel(),
                tc = c.newLabel();
            if (tail) {
                // a self tail call: a loop
                int other = c.newLabel();
                c.aload(tF); c.aload(SELF); c.jump(IF_ACMPNE, other);
                c.aload(tFrame); c.astore(FRAME);
                c.jump(GOTO, start);
                c.mark(other);
            }
            c.aload(tF); c.type(INSTANCEOF, LAM); c.jump(IFEQ, prim);
            c.aload(tF); c.type(CHECKCAST, LAM); c.astore(tLam);
            c.aload(tLam); c.field(GETFIELD, LAM, "cl", "Lscheme/CodeList;");
            c.field(GETFIELD, "scheme/CodeList", "jit", "Lscheme/jit/JitCode;");
            c.astore(tJit);
            if (tail) { c.iload(DEPTH); c.iconst(tailDepth); c.jump(IF_ICMPGE, tc); }
            c.aload(tJit); c.jump(IFNULL, interp);
            if (!tail) { c.iload(DEPTH); c.iconst(maxDepth); c.jump(IF_ICMPGE, interp); }
            c.aload(tJit); c.aload(VM_); c.aload(tLam); c.aload(tFrame); c.iload(DEPTH); c.iconst(1); c.op(IADD);
            c.invoke(INVOKEVIRTUAL, JITC, "call", CALL_DESC);
            if (tail) c.op(ARETURN); else c.jump(GOTO, got);
            c.mark(interp);
            c.aload(VM_); c.aload(tLam); c.aload(tFrame); c.iload(DEPTH);
            rt("interp", CALL_DESC.replace("(Lscheme/VM;Lscheme/Lambda;", "(Lscheme/VM;Lscheme/Lambda;"));
            if (tail) c.op(ARETURN); else c.jump(GOTO, done);
            if (tail) {
                c.mark(tc);
                c.aload(tLam); c.aload(tFrame); rt("tailCall", "(Lscheme/Lambda;" + OBJA + ")" + OBJD);
                c.op(ARETURN);
            }
            c.mark(prim);
            c.aload(VM_); c.aload(tF); c.aload(tFrame); ins(ins);
            rt("prim", "(Lscheme/VM;" + OBJD + OBJA + INSD + ")" + OBJD);
            if (tail) { c.op(ARETURN); return; }
            c.jump(GOTO, done);
            c.mark(got);
            c.op(DUP); c.type(INSTANCEOF, "scheme/jit/TailCall"); c.jump(IFEQ, done);
            c.aload(VM_); c.op(SWAP); c.iload(DEPTH);
            rt("trampoline", "(Lscheme/VM;" + OBJD + "I)" + OBJD);
            c.mark(done);
            store(argBase);
        }

        // A call through Rt.call/Rt.tail: up to 4 arguments are passed
        // directly, more in a frame.
        void emitCompactInvoke(Instruction ins, int d, boolean tail, boolean global, int start) {
            int n = ins.i1;
            int argBase = global ? d - n : d - n - 1;
            if (tail) {
                // a self tail call: a loop
                if (global) { c.aload(VM_); ins(ins); rt("gvarCall", "(Lscheme/VM;Lscheme/Instruction;)" + OBJD); }
                else load(d - 1);
                c.astore(tF);
                int other = c.newLabel();
                c.aload(tF); c.aload(SELF); c.jump(IF_ACMPNE, other);
                array(argBase, n, true); c.astore(FRAME);
                c.jump(GOTO, start);
                c.mark(other);
            }
            c.aload(VM_);
            c.iload(DEPTH);
            boolean gcall = !tail && global;
            if (tail) c.aload(tF);
            else if (!global) load(d - 1);
            ins(ins);
            StringBuilder desc = new StringBuilder(gcall ? "(Lscheme/VM;I" + INSD : "(Lscheme/VM;I" + OBJD + INSD);
            if (n <= 4) {
                for (int k = 0; k < n; k++) { load(argBase + k); desc.append(OBJD); }
            } else {
                array(argBase, n, true);
                desc.append(OBJA);
            }
            desc.append(")" + OBJD);
            rt((tail ? "tail" : gcall ? "gcall" : "call") + (n <= 4 ? String.valueOf(n) : "N"), desc.toString());
            if (tail) c.op(ARETURN); else store(argBase);
        }
    }
}
