using System.Reflection;
using System.Reflection.Emit;

namespace scheme;

// Compiles the code of a lambda to a .NET method once the interpreter has
// called it Jit.Threshold times (CodeList.calls). The method keeps the
// lambda's environment as the interpreter's object[] frames and its
// operand stack in local variables (one per stack slot, whose depth is
// static: Analyze), so that compiled and interpreted code share closures
// and a compiled frame can be turned into the interpreter's frame
// (Rt.Filter, Rt.Unwind). Code the translation does not support stays
// interpreted. Each lambda becomes a class in a dynamic assembly, so that
// its method takes part in tiered and profile-guided compilation.
//
// Environment variables: SCM_JIT=off disables it, SCM_JIT_THRESHOLD (calls
// before compiling, 0 compiles on the first call), SCM_JIT_STATS=true
// prints counters at exit, SCM_JIT_DEBUG=true reports compiled and
// rejected code, SCM_JIT_COMPACT=true forces compact call sites.
public static class Jit
{
    private static string? Env(string name) => Environment.GetEnvironmentVariable(name);
    private static int EnvInt(string name, int dflt) => int.TryParse(Env(name), out int v) ? v : dflt;

    public static readonly bool Enabled = Env("SCM_JIT") != "off";
    public static readonly int Threshold = Enabled ? EnvInt("SCM_JIT_THRESHOLD", 100) : -1;
    // compiled calls beyond MaxDepth run in the interpreter; tail calls
    // beyond TailDepth are returned to the nearest non-tail caller
    public static readonly int MaxDepth = EnvInt("SCM_JIT_MAXDEPTH", 400);
    public static readonly int TailDepth = EnvInt("SCM_JIT_TAILDEPTH", 200);
    internal static readonly bool Debug = Env("SCM_JIT_DEBUG") == "true";
    internal static readonly bool ForceCompact = Env("SCM_JIT_COMPACT") == "true";
    // counters (approximate: not synchronized)
    public static readonly bool Stats = Env("SCM_JIT_STATS") == "true";
    public static long statCompiled, statRejected, statNested, statCaptures, statErrors, statJumps,
        statTailCalls, statEscapes;
    private static readonly Dictionary<CodeList, long> nestedCounts = new(ReferenceEqualityComparer.Instance);
    // full call sites beyond this many IL bytes: compact code instead
    private const int MaxIL = 16000;

    static Jit()
    {
        if (Stats) AppDomain.CurrentDomain.ProcessExit += (_, _) =>
        {
            Console.Error.WriteLine("jit stats: compiled " + statCompiled + ", rejected " + statRejected
                + ", nested activations " + statNested + ", full captures " + statCaptures
                + ", unwound errors " + statErrors + ", escape continuations " + statEscapes
                + ", continuation jumps " + statJumps + ", trampolined tail calls " + statTailCalls);
            lock (nestedCounts)
            {
                foreach (var kv in nestedCounts.OrderByDescending(kv => kv.Value).Take(15))
                    Console.Error.WriteLine("  nested " + kv.Value + " "
                        + (kv.Key.jitRejected ? "rejected " : kv.Key.jit != null ? "compiled " : "")
                        + "calls=" + kv.Key.calls + " " + Describe(kv.Key));
            }
        };
    }

    public static void CountNested(CodeList cl)
    {
        lock (nestedCounts) nestedCounts[cl] = nestedCounts.GetValueOrDefault(cl) + 1;
    }

    // Compiles cl, or marks it rejected.
    public static void Compile(CodeList cl)
    {
        if (cl.jit != null || cl.jitRejected) return;
        try
        {
            var t = new Translator(cl, ForceCompact);
            JitCode? jit = t.Translate();
            if (jit == null && t.tooLarge) jit = new Translator(cl, true).Translate();
            if (jit == null) cl.jitRejected = true;
            else cl.jit = jit;
            if (Stats) { if (jit == null) statRejected++; else statCompiled++; }
            if (Debug) Console.Error.WriteLine("jit: " + (jit == null ? "rejected " : "compiled ") + Describe(cl));
        }
        catch (Exception e)
        {
            cl.jitRejected = true;
            if (Debug) Console.Error.WriteLine("jit: " + e);
        }
    }

    private static string Describe(CodeList cl)
    {
        var code = cl.Array();
        var pos = code.Length > 0 ? code[0].pos : null;
        var ops = new System.Text.StringBuilder();
        foreach (var i in code)
        {
            ops.Append(' ').Append(i.opcode);
            if (ops.Length > 120) break;
        }
        return (pos != null ? pos.ToString() : "?") + ops;
    }

    [ThreadStatic] private static object[]? constants;

    // Called by the static constructor of a generated class.
    public static object[] TakeConstants()
    {
        var c = constants!;
        constants = null;
        return c;
    }

    // ---- analysis ----

    // The operand stack depth before each instruction (-1 if unreachable),
    // or null if the code cannot be compiled.
    internal static int[]? Analyze(Instruction[] code)
    {
        int n = code.Length;
        if (n == 0) return null;
        if (code[0].opcode != Opcode.ARGS && code[0].opcode != Opcode.ARGSDOT) return null;
        var depth = new int[n];
        Array.Fill(depth, -1);
        var work = new int[n];
        int top = 0;
        depth[0] = 0;
        work[top++] = 0;
        while (top > 0)
        {
            int i = work[--top];
            int d = depth[i];
            Instruction ins = code[i];
            int next = d, target = -1, targetDepth = -1;
            bool falls = true;
            switch (ins.opcode)
            {
                case Opcode.ARGS: case Opcode.ARGSDOT:
                    if (i != 0) return null;
                    break;
                case Opcode.LVAR: case Opcode.GVAR: case Opcode.CONST: case Opcode.FN:
                case Opcode.LVAR_ADD_IMM: case Opcode.LVAR_SUB_IMM: case Opcode.LVAR_CAR:
                case Opcode.LVAR_CDR: case Opcode.LVAR_VREF:
                    next = d + 1; break;
                case Opcode.POPENV:
                    break;
                case Opcode.LSET: case Opcode.GSET:
                case Opcode.CAR: case Opcode.CDR: case Opcode.NOT: case Opcode.IS_NULL:
                case Opcode.IS_PAIR: case Opcode.CXR:
                    if (d < 1) return null;
                    break;
                case Opcode.POP: case Opcode.CONS: case Opcode.EQ_P: case Opcode.EQV_P: case Opcode.VECTOR_REF:
                    next = d - 1; break;
                case Opcode.VECTOR_SET:
                    next = d - 2; break;
                case Opcode.ADD: case Opcode.SUB: case Opcode.MUL: case Opcode.DIV:
                case Opcode.NUM_EQ: case Opcode.NUM_LT: case Opcode.NUM_GT: case Opcode.NUM_LTE:
                case Opcode.NUM_GTE: case Opcode.LIST:
                    if (ins.i1 < 0) return null;
                    next = d - ins.i1 + 1; break;
                case Opcode.JUMP:
                    falls = false; target = ins.i1; targetDepth = d; break;
                case Opcode.FJUMP: case Opcode.TJUMP:
                    next = d - 1; target = ins.i1; targetDepth = d - 1; break;
                case Opcode.TJUMP_KEEP:
                    next = d - 1; target = ins.i1; targetDepth = d; break;
                case Opcode.LVAR_NULL_FJUMP: case Opcode.LVAR_PAIR_FJUMP:
                    target = ins.i3; targetDepth = d; break;
                case Opcode.CONST_EQ_FJUMP:
                    next = d - 1; target = ins.i2; targetDepth = d - 1; break;
                case Opcode.RETURN:
                    if (d != 1) return null;
                    falls = false; break;
                case Opcode.CALLS:
                    if (ins.i1 < 0) return null;
                    next = d - ins.i1; break;
                case Opcode.GCALLS:
                    if (ins.i1 < 0) return null;
                    next = d - ins.i1 + 1; break;
                case Opcode.CALLJ:
                    if (ins.i1 < 0 || d != ins.i1 + 1) return null;
                    falls = false; break;
                case Opcode.GCALLJ:
                    if (ins.i1 < 0 || d != ins.i1) return null;
                    falls = false; break;
                case Opcode.EXTEND:
                    next = d - ins.i1; break;
                case Opcode.LOOP:
                    falls = false; target = ins.i3; targetDepth = d - ins.i1; break;
                default:
                    return null;
            }
            if (next < 0 || (target >= 0 && targetDepth < 0)) return null;
            if (falls)
            {
                if (i + 1 >= n) return null;
                if (depth[i + 1] < 0) { depth[i + 1] = next; work[top++] = i + 1; }
                else if (depth[i + 1] != next) return null;
            }
            if (target >= 0)
            {
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
    public static bool EscapeOnly(Lambda f)
    {
        CodeList cl = f.cl;
        if (cl.escapeOnly == 0) cl.escapeOnly = ComputeEscapeOnly(f.codeArr) ? (byte)1 : (byte)2;
        return cl.escapeOnly == 1;
    }

    private static bool ComputeEscapeOnly(Instruction[] code)
    {
        if (code.Length == 0 || code[0].opcode != Opcode.ARGS || code[0].i1 != 1) return false;
        return ScanEscape(code, 0, false);
    }

    // Data flow over code with the number of environment frames above its
    // own argument frame; the parameter's frame is that number plus
    // kOffset. In the receiver itself (not nested) the parameter may only
    // be called directly; nested code may not refer to it at all.
    private static bool ScanEscape(Instruction[] code, int kOffset, bool nested)
    {
        if (code.Length == 0) return true;
        var env = new int[code.Length];
        Array.Fill(env, -1);
        env[0] = 0;
        var work = new int[code.Length];
        int top = 0;
        work[top++] = 0;
        while (top > 0)
        {
            int i = work[--top];
            int e = env[i];
            int k = e + kOffset;
            Instruction ins = code[i];
            int next = e, target = -1, targetEnv = e;
            bool falls = true;
            switch (ins.opcode)
            {
                case Opcode.LVAR:
                    if (ins.i1 == k && ins.i2 == 0)
                    {
                        if (nested || i + 1 >= code.Length) return false;
                        var op = code[i + 1].opcode;
                        if (op != Opcode.CALLS && op != Opcode.CALLJ) return false;
                    }
                    break;
                case Opcode.LSET: case Opcode.LVAR_CAR: case Opcode.LVAR_CDR: case Opcode.LVAR_VREF:
                case Opcode.FLATTEN_APPLY:
                    if (ins.i1 == k && ins.i2 == 0) return false;
                    break;
                case Opcode.LVAR_NULL_FJUMP: case Opcode.LVAR_PAIR_FJUMP:
                    if (ins.i1 == k && ins.i2 == 0) return false;
                    target = ins.i3;
                    break;
                case Opcode.LVAR_ADD_IMM: case Opcode.LVAR_SUB_IMM:
                {
                    long packed = (long)ins.arg1!;
                    if ((int)(packed >> 16) == k && (packed & 0xFFFF) == 0) return false;
                    break;
                }
                case Opcode.FN:
                    if (!ScanEscape(FnCode(ins).ToArray(), 1 + k, true)) return false;
                    break;
                case Opcode.EXTEND: next = e + 1; break;
                case Opcode.POPENV: next = e - 1; break;
                case Opcode.JUMP: falls = false; target = ins.i1; break;
                case Opcode.FJUMP: case Opcode.TJUMP: case Opcode.TJUMP_KEEP: target = ins.i1; break;
                case Opcode.CONST_EQ_FJUMP: target = ins.i2; break;
                case Opcode.LOOP: falls = false; target = ins.i3; targetEnv = e - ins.i2 + 1; break;
                case Opcode.RETURN: case Opcode.CALLJ: case Opcode.GCALLJ: falls = false; break;
                case Opcode.ARGS: case Opcode.ARGSDOT: if (i != 0) return false; break;
                case Opcode.ARGMV: case Opcode.SAVE: case Opcode.CC: case Opcode.ECC: case Opcode.SETCC:
                case Opcode.FLATTEN_MULTVALS:
                    if (!nested) return false;
                    break;
                default: break;
            }
            if (next < 0 || targetEnv < 0) return false;
            if (falls && i + 1 < code.Length && env[i + 1] < 0) { env[i + 1] = next; work[top++] = i + 1; }
            if (target >= 0 && target < code.Length && env[target] < 0) { env[target] = targetEnv; work[top++] = target; }
        }
        return true;
    }

    private static List<Instruction> FnCode(Instruction ins) => (List<Instruction>)Value.AsPair(ins.arg1!).Sixth();

    // ---- translation ----

    private static readonly ModuleBuilder module = AssemblyBuilder
        .DefineDynamicAssembly(new AssemblyName("scm-jit"), AssemblyBuilderAccess.Run)
        .DefineDynamicModule("scm-jit");
    private static int counter;

    private static readonly MethodInfo CallMethod = typeof(JitCode).GetMethod(nameof(JitCode.Call))!;
    private static readonly FieldInfo LambdaEnv = typeof(Lambda).GetField(nameof(Lambda.env))!;
    private static readonly FieldInfo LambdaCl = typeof(Lambda).GetField(nameof(Lambda.cl))!;
    private static readonly FieldInfo CodeListJit = typeof(CodeList).GetField(nameof(CodeList.jit))!;
    private static readonly FieldInfo PairCar = typeof(Pair).GetField(nameof(Pair.car))!;
    private static readonly FieldInfo PairCdr = typeof(Pair).GetField(nameof(Pair.cdr))!;
    private static readonly FieldInfo ValueNil = typeof(Value).GetField(nameof(Value.NIL))!;
    private static readonly ConstructorInfo PairNew = typeof(Pair).GetConstructor(new[] { typeof(object), typeof(object) })!;
    private static MethodInfo RtM(string name) => typeof(Rt).GetMethod(name)
        ?? throw new InvalidOperationException("Rt." + name);

    private sealed class Translator
    {
        readonly CodeList cl;
        readonly Instruction[] code;
        readonly bool compact;
        internal bool tooLarge;
        int[] depths = null!;
        int[] levels = null!;
        int maxLevel, maxOuter, lvl;
        bool[] target = null!;
        TypeBuilder tb = null!;
        ILGenerator il = null!;
        Label[] label = null!;
        Label start, ret;
        LocalBuilder env = null!, tF = null!, tLam = null!, tJit = null!, tFrame = null!, tX = null!,
            ipL = null!, result = null!, tSlots = null!, tExc = null!;
        LocalBuilder[] slots = null!, fLocals = null!, oLocals = null!;
        readonly List<object?> consts = new();
        readonly List<FieldBuilder> constFields = new();
        readonly Dictionary<object, int> constIndex = new(ReferenceEqualityComparer.Instance);

        internal Translator(CodeList cl, bool compact)
        {
            this.cl = cl;
            this.code = cl.Array();
            this.compact = compact;
        }

        // the static readonly field holding v
        void Const(object v, Type type)
        {
            if (!constIndex.TryGetValue(v, out int k) || constFields[k].FieldType != type)
            {
                k = consts.Count;
                consts.Add(v);
                constFields.Add(tb.DefineField("K" + k, type,
                    FieldAttributes.Private | FieldAttributes.Static | FieldAttributes.InitOnly));
                constIndex[v] = k;
            }
            il.Emit(OpCodes.Ldsfld, constFields[k]);
        }

        void Ins(Instruction i) => Const(i, typeof(Instruction));

        void Rt(string name) => il.Emit(OpCodes.Call, RtM(name));

        void Load(int k) => il.Emit(OpCodes.Ldloc, slots[k]);
        void Store(int k) => il.Emit(OpCodes.Stloc, slots[k]);
        void Ldc(int v) => il.Emit(OpCodes.Ldc_I4, v);

        internal JitCode? Translate()
        {
            var d0 = Analyze(code);
            if (d0 == null) return null;
            depths = d0;
            cl.depths = depths;
            if (!AnalyzeLevels()) return null;
            int maxSlots = 1;
            foreach (int d in depths) if (d + 1 > maxSlots) maxSlots = d + 1;
            target = new bool[code.Length];
            foreach (var ins in code)
            {
                switch (ins.opcode)
                {
                    case Opcode.JUMP: case Opcode.FJUMP: case Opcode.TJUMP: case Opcode.TJUMP_KEEP:
                        target[ins.i1] = true; break;
                    case Opcode.LOOP: case Opcode.LVAR_NULL_FJUMP: case Opcode.LVAR_PAIR_FJUMP:
                        target[ins.i3] = true; break;
                    case Opcode.CONST_EQ_FJUMP:
                        target[ins.i2] = true; break;
                }
            }
            lock (module)
            {
                tb = module.DefineType("scm.L" + (++counter),
                    TypeAttributes.Public | TypeAttributes.Sealed | TypeAttributes.Class, typeof(JitCode));
                var mb = tb.DefineMethod("Call",
                    MethodAttributes.Public | MethodAttributes.Virtual | MethodAttributes.HideBySig,
                    typeof(object), new[] { typeof(VM), typeof(Lambda), typeof(object[]), typeof(int) });
                il = mb.GetILGenerator();
                env = il.DeclareLocal(typeof(object));
                slots = new LocalBuilder[maxSlots];
                for (int k = 0; k < maxSlots; k++) slots[k] = il.DeclareLocal(typeof(object));
                fLocals = new LocalBuilder[maxLevel + 1];
                for (int k = 0; k <= maxLevel; k++) fLocals[k] = il.DeclareLocal(typeof(object[]));
                oLocals = new LocalBuilder[maxOuter + 1];
                for (int k = 1; k <= maxOuter; k++) oLocals[k] = il.DeclareLocal(typeof(object[]));
                tF = il.DeclareLocal(typeof(object));
                tLam = il.DeclareLocal(typeof(Lambda));
                tJit = il.DeclareLocal(typeof(JitCode));
                tFrame = il.DeclareLocal(typeof(object[]));
                tX = il.DeclareLocal(typeof(object));
                ipL = il.DeclareLocal(typeof(int));
                result = il.DeclareLocal(typeof(object));
                tSlots = il.DeclareLocal(typeof(object[]));
                tExc = il.DeclareLocal(typeof(Exception));
                EmitBody();
                if (il.ILOffset > MaxIL && !compact)
                {
                    tooLarge = true;
                    if (Debug) Console.Error.WriteLine("jit: too large: " + il.ILOffset);
                    return null;
                }
                // the static constructor takes the constants
                var cctor = tb.DefineTypeInitializer().GetILGenerator();
                var cs = cctor.DeclareLocal(typeof(object[]));
                cctor.Emit(OpCodes.Call, typeof(Jit).GetMethod(nameof(TakeConstants))!);
                cctor.Emit(OpCodes.Stloc, cs);
                for (int k = 0; k < consts.Count; k++)
                {
                    cctor.Emit(OpCodes.Ldloc, cs);
                    cctor.Emit(OpCodes.Ldc_I4, k);
                    cctor.Emit(OpCodes.Ldelem_Ref);
                    if (constFields[k].FieldType != typeof(object))
                        cctor.Emit(OpCodes.Castclass, constFields[k].FieldType);
                    cctor.Emit(OpCodes.Stsfld, constFields[k]);
                }
                cctor.Emit(OpCodes.Ret);
                Type type = tb.CreateType()!;
                constants = consts.ToArray()!;
                try
                {
                    return (JitCode)Activator.CreateInstance(type)!;
                }
                finally
                {
                    constants = null;
                }
            }
        }

        // The environment level before each instruction (-1 before ARGS):
        // F(k) holds the frame k levels above the argument frame F(0)
        // (EXTEND/LOOP), O(k) the frame k levels above F(0)'s parent.
        bool AnalyzeLevels()
        {
            int n = code.Length;
            levels = new int[n];
            Array.Fill(levels, -2);
            levels[0] = -1;
            var work = new int[n];
            int top = 0;
            work[top++] = 0;
            while (top > 0)
            {
                int i = work[--top];
                int l = levels[i];
                Instruction ins = code[i];
                int next = l, tgt = -1, targetLevel = l, refd = -1;
                bool falls = true;
                switch (ins.opcode)
                {
                    case Opcode.ARGS: case Opcode.ARGSDOT: next = 0; break;
                    case Opcode.EXTEND: next = l + 1; break;
                    case Opcode.POPENV: next = l - 1; break;
                    case Opcode.LVAR: case Opcode.LSET: case Opcode.LVAR_CAR: case Opcode.LVAR_CDR:
                    case Opcode.LVAR_VREF: refd = ins.i1; break;
                    case Opcode.LVAR_NULL_FJUMP: case Opcode.LVAR_PAIR_FJUMP: refd = ins.i1; tgt = ins.i3; break;
                    case Opcode.LVAR_ADD_IMM: case Opcode.LVAR_SUB_IMM: refd = (int)((long)ins.arg1! >> 16); break;
                    case Opcode.JUMP: falls = false; tgt = ins.i1; break;
                    case Opcode.FJUMP: case Opcode.TJUMP: case Opcode.TJUMP_KEEP: tgt = ins.i1; break;
                    case Opcode.CONST_EQ_FJUMP: tgt = ins.i2; break;
                    case Opcode.LOOP: falls = false; tgt = ins.i3; targetLevel = l - ins.i2 + 1; refd = ins.i2; break;
                    case Opcode.RETURN: case Opcode.CALLJ: case Opcode.GCALLJ: falls = false; break;
                }
                if (refd > l) maxOuter = Math.Max(maxOuter, refd - l);
                if (next < 0 || (tgt >= 0 && targetLevel < 0)) return false;
                if (next > maxLevel) maxLevel = next;
                if (falls && i + 1 < n)
                {
                    if (levels[i + 1] == -2) { levels[i + 1] = next; work[top++] = i + 1; }
                    else if (levels[i + 1] != next) return false;
                }
                if (tgt >= 0)
                {
                    if (levels[tgt] == -2) { levels[tgt] = targetLevel; work[top++] = tgt; }
                    else if (levels[tgt] != targetLevel) return false;
                }
            }
            return true;
        }

        // the frame frames levels up from the current environment
        void FrameAt(int frames)
        {
            if (frames <= lvl) il.Emit(OpCodes.Ldloc, fLocals[lvl - frames]);
            else il.Emit(OpCodes.Ldloc, oLocals[frames - lvl]);
        }

        void Getenv(int frame, int var)
        {
            FrameAt(frame);
            Ldc(var + 1);
            il.Emit(OpCodes.Ldelem_Ref);
        }

        // after ARGS/ARGSDOT: the closure's frames
        void EnterFrames()
        {
            for (int k = 1; k <= maxOuter; k++)
            {
                if (k == 1) { il.Emit(OpCodes.Ldarg_2); il.Emit(OpCodes.Ldfld, LambdaEnv); }
                else { il.Emit(OpCodes.Ldloc, oLocals[k - 1]); Ldc(0); il.Emit(OpCodes.Ldelem_Ref); }
                il.Emit(OpCodes.Castclass, typeof(object[]));
                il.Emit(OpCodes.Stloc, oLocals[k]);
            }
        }

        // a new object[n] of slots from..from+n-1, with an empty index 0 if frame
        void NewArray(int from, int n, bool frame)
        {
            int off = frame ? 1 : 0;
            Ldc(n + off);
            il.Emit(OpCodes.Newarr, typeof(object));
            for (int k = 0; k < n; k++)
            {
                il.Emit(OpCodes.Dup); Ldc(k + off); Load(from + k); il.Emit(OpCodes.Stelem_Ref);
            }
        }

        // Whether an instruction can throw (and so sets the ip local).
        static bool CanThrow(Opcode op)
        {
            switch (op)
            {
                case Opcode.CONST: case Opcode.POP: case Opcode.JUMP: case Opcode.FJUMP: case Opcode.TJUMP:
                case Opcode.TJUMP_KEEP: case Opcode.RETURN: case Opcode.LVAR: case Opcode.LSET:
                case Opcode.POPENV: case Opcode.EXTEND: case Opcode.FN: case Opcode.CONS: case Opcode.LIST:
                case Opcode.IS_NULL: case Opcode.IS_PAIR: case Opcode.NOT: case Opcode.EQ_P: case Opcode.EQV_P:
                case Opcode.LVAR_NULL_FJUMP: case Opcode.LVAR_PAIR_FJUMP: case Opcode.CONST_EQ_FJUMP:
                    return false;
                default:
                    return true;
            }
        }

        void EmitBody()
        {
            ret = il.DefineLabel();
            label = new Label[code.Length];
            for (int i = 0; i < code.Length; i++) label[i] = il.DefineLabel();
            il.BeginExceptionBlock();
            start = il.DefineLabel();
            il.MarkLabel(start);
            for (int i = 0; i < code.Length; i++)
            {
                il.MarkLabel(label[i]);
                if (depths[i] < 0) continue;
                lvl = levels[i];
                if (i == 0 || CanThrow(code[i].opcode)) { Ldc(i); il.Emit(OpCodes.Stloc, ipL); }
                if (i == 0) { il.Emit(OpCodes.Ldarg_1); Rt("CheckTerm"); }
                if (Emit(i)) { i++; il.MarkLabel(label[i]); }
            }
            // the filter: captures and jumps pass on, errors raised here are caught
            il.BeginExceptFilterBlock();
            il.Emit(OpCodes.Stloc, tExc);
            NewArray(0, slots.Length, false);
            il.Emit(OpCodes.Stloc, tSlots);
            il.Emit(OpCodes.Ldloc, tExc);
            il.Emit(OpCodes.Ldarg_2);
            il.Emit(OpCodes.Ldloc, ipL);
            il.Emit(OpCodes.Ldloc, env);
            il.Emit(OpCodes.Ldloc, tSlots);
            Rt("Filter");
            il.BeginCatchBlock(null);
            il.Emit(OpCodes.Pop);
            il.Emit(OpCodes.Ldloc, tExc);
            il.Emit(OpCodes.Ldarg_1);
            il.Emit(OpCodes.Ldarg_2);
            il.Emit(OpCodes.Ldloc, ipL);
            il.Emit(OpCodes.Ldloc, env);
            il.Emit(OpCodes.Ldloc, tSlots);
            il.Emit(OpCodes.Ldarg, 4);
            Rt("Unwind");
            il.Emit(OpCodes.Throw);
            il.EndExceptionBlock();
            il.MarkLabel(ret);
            il.Emit(OpCodes.Ldloc, result);
            il.Emit(OpCodes.Ret);
        }

        void Return() { il.Emit(OpCodes.Stloc, result); il.Emit(OpCodes.Leave, ret); }

        // Returns true if instruction i + 1 was fused into i.
        bool Emit(int i)
        {
            Instruction ins = code[i];
            int d = depths[i];
            switch (ins.opcode)
            {
                case Opcode.ARGS:
                {
                    var ok = il.DefineLabel();
                    il.Emit(OpCodes.Ldarg_3); il.Emit(OpCodes.Ldlen); il.Emit(OpCodes.Conv_I4); Ldc(ins.i1 + 1);
                    il.Emit(OpCodes.Beq, ok);
                    il.Emit(OpCodes.Ldarg_2); Ins(ins);
                    il.Emit(OpCodes.Ldarg_3); il.Emit(OpCodes.Ldlen); il.Emit(OpCodes.Conv_I4); Ldc(1); il.Emit(OpCodes.Sub);
                    Rt("Arity");
                    il.Emit(OpCodes.Throw);
                    il.MarkLabel(ok);
                    il.Emit(OpCodes.Ldarg_3); Ldc(0); il.Emit(OpCodes.Ldarg_2); il.Emit(OpCodes.Ldfld, LambdaEnv);
                    il.Emit(OpCodes.Stelem_Ref);
                    il.Emit(OpCodes.Ldarg_3); il.Emit(OpCodes.Dup); il.Emit(OpCodes.Stloc, env);
                    il.Emit(OpCodes.Stloc, fLocals[0]);
                    EnterFrames();
                    return false;
                }
                case Opcode.ARGSDOT:
                    il.Emit(OpCodes.Ldarg_2); Ins(ins); il.Emit(OpCodes.Ldarg_3);
                    Rt("ArgsDot");
                    il.Emit(OpCodes.Dup); il.Emit(OpCodes.Stloc, env); il.Emit(OpCodes.Stloc, fLocals[0]);
                    EnterFrames();
                    return false;
                case Opcode.LVAR:
                    Getenv(ins.i1, ins.i2); Store(d);
                    return false;
                case Opcode.LSET:
                    FrameAt(ins.i1); Ldc(ins.i2 + 1); Load(d - 1); Rt("Pv"); il.Emit(OpCodes.Stelem_Ref);
                    return false;
                case Opcode.GVAR:
                    il.Emit(OpCodes.Ldarg_1); Ins(ins); Rt("Gvar"); Store(d);
                    return false;
                case Opcode.GSET:
                    il.Emit(OpCodes.Ldarg_1); Ins(ins); Load(d - 1); Rt("Gset");
                    return false;
                case Opcode.POP:
                    return false;
                case Opcode.CONST:
                    if (ins.arg1 == null) il.Emit(OpCodes.Ldnull); else Const(ins.arg1, typeof(object));
                    Store(d);
                    return false;
                case Opcode.JUMP:
                    il.Emit(OpCodes.Br, label[ins.i1]);
                    return false;
                case Opcode.FJUMP: case Opcode.TJUMP:
                    Load(d - 1); Rt("IsFalse");
                    il.Emit(ins.opcode == Opcode.FJUMP ? OpCodes.Brtrue : OpCodes.Brfalse, label[ins.i1]);
                    return false;
                case Opcode.TJUMP_KEEP:
                    Load(d - 1); Rt("IsFalse"); il.Emit(OpCodes.Brfalse, label[ins.i1]);
                    return false;
                case Opcode.RETURN:
                    Load(d - 1); Return();
                    return false;
                case Opcode.CALLS: EmitInvoke(ins, d, false, false); return false;
                case Opcode.GCALLS: EmitInvoke(ins, d, false, true); return false;
                case Opcode.CALLJ: EmitInvoke(ins, d, true, false); return false;
                case Opcode.GCALLJ: EmitInvoke(ins, d, true, true); return false;
                case Opcode.FN:
                {
                    Pair f = Value.AsPair(ins.arg1!);
                    string? doc = f.Length() > 6 ? f.Eight()?.ToString() : null;
                    il.Emit(OpCodes.Ldloc, env);
                    Const(FnCode(ins), typeof(List<Instruction>));
                    if (doc == null) il.Emit(OpCodes.Ldnull); else il.Emit(OpCodes.Ldstr, doc);
                    Rt("MakeLambda");
                    Store(d);
                    return false;
                }
                case Opcode.EXTEND:
                {
                    int n = ins.i1;
                    Ldc(n + 1); il.Emit(OpCodes.Newarr, typeof(object));
                    il.Emit(OpCodes.Dup); Ldc(0); il.Emit(OpCodes.Ldloc, env); il.Emit(OpCodes.Stelem_Ref);
                    for (int k = 1; k <= n; k++) { il.Emit(OpCodes.Dup); Ldc(k); Load(d - n + k - 1); il.Emit(OpCodes.Stelem_Ref); }
                    il.Emit(OpCodes.Dup); il.Emit(OpCodes.Stloc, env);
                    il.Emit(OpCodes.Stloc, fLocals[lvl + 1]);
                    return false;
                }
                case Opcode.POPENV:
                    il.Emit(OpCodes.Ldloc, fLocals[lvl - 1]); il.Emit(OpCodes.Stloc, env);
                    return false;
                case Opcode.LOOP:
                {
                    int n = ins.i1;
                    il.Emit(OpCodes.Ldarg_1); Rt("CheckTerm");
                    Ldc(n + 1); il.Emit(OpCodes.Newarr, typeof(object));
                    il.Emit(OpCodes.Dup); Ldc(0); FrameAt(ins.i2); il.Emit(OpCodes.Stelem_Ref);
                    for (int k = 1; k <= n; k++) { il.Emit(OpCodes.Dup); Ldc(k); Load(d - n + k - 1); il.Emit(OpCodes.Stelem_Ref); }
                    il.Emit(OpCodes.Dup); il.Emit(OpCodes.Stloc, env);
                    il.Emit(OpCodes.Stloc, fLocals[lvl - ins.i2 + 1]);
                    il.Emit(OpCodes.Br, label[ins.i3]);
                    return false;
                }
                case Opcode.CAR: case Opcode.CDR:
                    Load(d - 1); Rt("AsPair");
                    il.Emit(OpCodes.Ldfld, ins.opcode == Opcode.CAR ? PairCar : PairCdr);
                    Store(d - 1);
                    return false;
                case Opcode.LVAR_CAR: case Opcode.LVAR_CDR:
                    Getenv(ins.i1, ins.i2); Rt("AsPair");
                    il.Emit(OpCodes.Ldfld, ins.opcode == Opcode.LVAR_CAR ? PairCar : PairCdr);
                    Store(d);
                    return false;
                case Opcode.CONS:
                    Load(d - 2); Load(d - 1); il.Emit(OpCodes.Newobj, PairNew); Store(d - 2);
                    return false;
                case Opcode.CXR:
                    Load(d - 1); Ldc(ins.i1); Rt("Cxr"); Store(d - 1);
                    return false;
                case Opcode.LIST:
                {
                    int n = ins.i1;
                    il.Emit(OpCodes.Ldsfld, ValueNil); il.Emit(OpCodes.Stloc, tX);
                    for (int k = n - 1; k >= 0; k--)
                    {
                        Load(d - n + k); il.Emit(OpCodes.Ldloc, tX); il.Emit(OpCodes.Newobj, PairNew);
                        il.Emit(OpCodes.Stloc, tX);
                    }
                    il.Emit(OpCodes.Ldloc, tX); Store(d - n);
                    return false;
                }
                case Opcode.VECTOR_REF:
                    Load(d - 2); Load(d - 1); Ins(ins); Rt("VectorRef"); Store(d - 2);
                    return false;
                case Opcode.VECTOR_SET:
                    Load(d - 3); Load(d - 2); Load(d - 1); Ins(ins); Rt("VectorSet"); Store(d - 3);
                    return false;
                case Opcode.LVAR_VREF:
                    Getenv(ins.i1, ins.i2); Ldc(ins.i3); Ins(ins); Rt("VrefConst"); Store(d);
                    return false;
                case Opcode.LVAR_ADD_IMM: case Opcode.LVAR_SUB_IMM:
                {
                    long packed = (long)ins.arg1!;
                    Getenv((int)(packed >> 16), (int)(packed & 0xFFFF));
                    il.Emit(OpCodes.Ldc_I8, (long)ins.arg2!);
                    Rt(ins.opcode == Opcode.LVAR_ADD_IMM ? "AddImm" : "SubImm");
                    Store(d);
                    return false;
                }
                case Opcode.LVAR_NULL_FJUMP:
                    Getenv(ins.i1, ins.i2); il.Emit(OpCodes.Ldsfld, ValueNil); il.Emit(OpCodes.Bne_Un, label[ins.i3]);
                    return false;
                case Opcode.LVAR_PAIR_FJUMP:
                    Getenv(ins.i1, ins.i2); Rt("IsPair"); il.Emit(OpCodes.Brfalse, label[ins.i3]);
                    return false;
                case Opcode.CONST_EQ_FJUMP:
                    Load(d - 1);
                    if (ins.arg1 == null) il.Emit(OpCodes.Ldnull); else Const(ins.arg1, typeof(object));
                    Rt("EqZ"); il.Emit(OpCodes.Brfalse, label[ins.i2]);
                    return false;
                default:
                    return EmitOperator(i, ins, d);
            }
        }

        // The value-producing intrinsics; a test followed by FJUMP/TJUMP
        // (not a jump target) branches on the boolean directly.
        bool EmitOperator(int i, Instruction ins, int d)
        {
            Instruction? next = i + 1 < code.Length && !target[i + 1] ? code[i + 1] : null;
            bool branch = next != null && (next.opcode == Opcode.FJUMP || next.opcode == Opcode.TJUMP);
            string? test = null, value;
            int arity = 2;
            bool withIns = false;
            switch (ins.opcode)
            {
                case Opcode.IS_NULL: arity = 1; value = "IsNull"; break;
                case Opcode.IS_PAIR: arity = 1; value = "IsPairO"; test = "IsPair"; break;
                case Opcode.NOT: arity = 1; value = "Not"; test = "IsFalse"; break;
                case Opcode.EQ_P: value = "Eq"; test = "EqZ"; break;
                case Opcode.EQV_P: value = "Eqv"; test = "EqvZ"; break;
                case Opcode.ADD: case Opcode.SUB: case Opcode.MUL: case Opcode.DIV:
                case Opcode.NUM_EQ: case Opcode.NUM_LT: case Opcode.NUM_GT: case Opcode.NUM_LTE: case Opcode.NUM_GTE:
                {
                    int n = ins.i1;
                    if (ins.opcode == Opcode.SUB && n == 1) { arity = 1; value = "Negate"; break; }
                    if (n != 2)
                    {
                        NewArray(d - n, n, false); Ins(ins); Rt("Nary"); Store(d - n);
                        return false;
                    }
                    switch (ins.opcode)
                    {
                        case Opcode.ADD: value = "Add"; break;
                        case Opcode.SUB: value = "Sub"; break;
                        case Opcode.MUL: value = "Mul"; break;
                        case Opcode.DIV: value = "Div"; withIns = true; break;
                        case Opcode.NUM_EQ: value = "NumEq"; test = "NumEqZ"; withIns = true; break;
                        case Opcode.NUM_LT: value = "NumLt"; test = "NumLtZ"; withIns = true; break;
                        case Opcode.NUM_GT: value = "NumGt"; test = "NumGtZ"; withIns = true; break;
                        case Opcode.NUM_LTE: value = "NumLte"; test = "NumLteZ"; withIns = true; break;
                        default: value = "NumGte"; test = "NumGteZ"; withIns = true; break;
                    }
                    break;
                }
                default:
                    throw new InvalidOperationException("jit: unsupported " + ins.opcode);
            }
            for (int k = arity; k >= 1; k--) Load(d - k);
            if (withIns) Ins(ins);
            if (branch && (test != null || ins.opcode == Opcode.IS_NULL))
            {
                bool jumpIfTrue = next!.opcode == Opcode.TJUMP;
                if (ins.opcode == Opcode.IS_NULL)
                {
                    il.Emit(OpCodes.Ldsfld, ValueNil);
                    il.Emit(jumpIfTrue ? OpCodes.Beq : OpCodes.Bne_Un, label[next.i1]);
                    return true;
                }
                // (not x) is true when x is false
                Rt(test!);
                il.Emit(jumpIfTrue ? OpCodes.Brtrue : OpCodes.Brfalse, label[next.i1]);
                return true;
            }
            Rt(value);
            Store(d - arity);
            return false;
        }

        // CALLS/GCALLS (non-tail) and CALLJ/GCALLJ (tail).
        void EmitInvoke(Instruction ins, int d, bool tail, bool global)
        {
            int n = ins.i1;
            int argBase = global ? d - n : d - n - 1;
            if (global) { il.Emit(OpCodes.Ldarg_1); Ins(ins); Rt("GvarCall"); }
            else Load(d - 1);
            il.Emit(OpCodes.Stloc, tF);
            if (tail)
            {
                // a self tail call: a loop
                var other = il.DefineLabel();
                il.Emit(OpCodes.Ldloc, tF); il.Emit(OpCodes.Ldarg_2); il.Emit(OpCodes.Bne_Un, other);
                NewArray(argBase, n, true); il.Emit(OpCodes.Starg, 3);
                il.Emit(OpCodes.Br, start);
                il.MarkLabel(other);
            }
            if (compact)
            {
                il.Emit(OpCodes.Ldarg_1); il.Emit(OpCodes.Ldarg, 4); il.Emit(OpCodes.Ldloc, tF);
                NewArray(argBase, n, true); Ins(ins);
                Rt(tail ? "TailF" : "CallF");
                if (tail) { Return(); return; }
                EscapeCheck();
                Store(argBase);
                return;
            }
            Label prim = il.DefineLabel(), interp = il.DefineLabel(), got = il.DefineLabel(),
                done = il.DefineLabel(), tc = il.DefineLabel();
            il.Emit(OpCodes.Ldloc, tF); il.Emit(OpCodes.Isinst, typeof(Lambda)); il.Emit(OpCodes.Stloc, tLam);
            il.Emit(OpCodes.Ldloc, tLam); il.Emit(OpCodes.Brfalse, prim);
            il.Emit(OpCodes.Ldloc, tLam); il.Emit(OpCodes.Ldfld, LambdaCl); il.Emit(OpCodes.Ldfld, CodeListJit);
            il.Emit(OpCodes.Stloc, tJit);
            NewArray(argBase, n, true); il.Emit(OpCodes.Stloc, tFrame);
            if (tail) { il.Emit(OpCodes.Ldarg, 4); Ldc(TailDepth); il.Emit(OpCodes.Bge, tc); }
            il.Emit(OpCodes.Ldloc, tJit); il.Emit(OpCodes.Brfalse, interp);
            if (!tail) { il.Emit(OpCodes.Ldarg, 4); Ldc(MaxDepth); il.Emit(OpCodes.Bge, interp); }
            il.Emit(OpCodes.Ldloc, tJit); il.Emit(OpCodes.Ldarg_1); il.Emit(OpCodes.Ldloc, tLam);
            il.Emit(OpCodes.Ldloc, tFrame); il.Emit(OpCodes.Ldarg, 4); Ldc(1); il.Emit(OpCodes.Add);
            il.Emit(OpCodes.Callvirt, CallMethod);
            if (tail) Return(); else il.Emit(OpCodes.Br, got);
            il.MarkLabel(interp);
            il.Emit(OpCodes.Ldarg_1); il.Emit(OpCodes.Ldloc, tLam); il.Emit(OpCodes.Ldloc, tFrame); il.Emit(OpCodes.Ldarg, 4);
            Rt("Interp");
            if (tail) Return(); else il.Emit(OpCodes.Br, got);
            if (tail)
            {
                il.MarkLabel(tc);
                il.Emit(OpCodes.Ldloc, tLam); il.Emit(OpCodes.Ldloc, tFrame); Rt("MakeTailCall");
                Return();
            }
            // not a lambda: the primitive's arguments, as primary values
            il.MarkLabel(prim);
            il.Emit(OpCodes.Ldloc, tF);
            Ldc(n); il.Emit(OpCodes.Newarr, typeof(object));
            for (int k = 0; k < n; k++)
            {
                il.Emit(OpCodes.Dup); Ldc(k); Load(argBase + k); Rt("Pv"); il.Emit(OpCodes.Stelem_Ref);
            }
            Ins(ins);
            Rt("PrimArgs");
            if (tail) { Return(); return; }
            il.Emit(OpCodes.Br, done);
            // a lambda's result: a Signal is acted on, an escape returned on
            il.MarkLabel(got);
            var plain = il.DefineLabel();
            il.Emit(OpCodes.Dup); il.Emit(OpCodes.Isinst, typeof(Signal)); il.Emit(OpCodes.Brfalse, plain);
            il.Emit(OpCodes.Stloc, tX);
            il.Emit(OpCodes.Ldarg_1); il.Emit(OpCodes.Ldloc, tX); il.Emit(OpCodes.Ldarg, 4);
            Rt("Signal");
            EscapeCheck();
            il.MarkLabel(plain);
            il.MarkLabel(done);
            Store(argBase);
        }

        // value on the stack: an EscapeSignal is returned on
        void EscapeCheck()
        {
            var value = il.DefineLabel();
            il.Emit(OpCodes.Dup); il.Emit(OpCodes.Isinst, typeof(EscapeSignal)); il.Emit(OpCodes.Brfalse, value);
            Return();
            il.MarkLabel(value);
        }
    }
}
