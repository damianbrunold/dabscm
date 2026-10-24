namespace scheme;

public class Compiler
{
    private Modules modules;
    private BindingTable bindingTable;

    // Intrinsic opcodes: bare calls to these names (when not shadowed) skip SAVE/GVAR/CALLJ
    private static readonly Dictionary<string, (Opcode op, int arity)> s_intrinsics = new()
    {
        ["car"]  = (Opcode.CAR,     1),
        ["cdr"]  = (Opcode.CDR,     1),
        ["cons"] = (Opcode.CONS,    2),
        ["null?"]= (Opcode.IS_NULL, 1),
        ["pair?"]= (Opcode.IS_PAIR, 1),
        ["not"]  = (Opcode.NOT,     1),
        ["+"]    = (Opcode.ADD,    -1),  // -1 = variable arity
        ["-"]    = (Opcode.SUB,    -1),
        ["*"]    = (Opcode.MUL,    -1),
        ["/"]    = (Opcode.DIV,    -1),
        ["="]    = (Opcode.NUM_EQ, -1),
        ["<"]    = (Opcode.NUM_LT, -1),
        [">"]    = (Opcode.NUM_GT, -1),
        ["<="]   = (Opcode.NUM_LTE,-1),
        [">="]   = (Opcode.NUM_GTE,-1),
        ["eq?"]  = (Opcode.EQ_P,   2),
        ["eqv?"] = (Opcode.EQV_P,  2),
        ["vector-ref"]  = (Opcode.VECTOR_REF,  2),
        ["vector-set!"] = (Opcode.VECTOR_SET,  3),
        ["list"] = (Opcode.LIST,   -1),
    };

    private static readonly string[] s_cxrNames =
    {
        "caar", "cadr", "cadar", "cdar", "cddr",
        "caaar", "caadr", "caddr", "cdaar", "cdadr", "cddar", "cdddr",
        "caaaar", "caaadr", "caadar", "caaddr", "cadaar", "cadadr", "caddar", "cadddr",
        "cdaaar", "cdaadr", "cdadar", "cdaddr", "cddaar", "cddadr", "cdddar", "cddddr"
    };

    static Compiler()
    {
        foreach (var name in s_cxrNames)
            s_intrinsics[name] = (Opcode.CXR, 1);
    }

    /// <summary>
    /// The car/cdr steps of a c[ad]+r name as bits, first step lowest
    /// (1 = cdr, 0 = car), above a leading 1: caddr -> 0b1011.
    /// </summary>
    public static int CxrPath(string name)
    {
        int path = 1;
        for (int i = 1; i < name.Length - 1; i++)
            path = (path << 1) | (name[i] == 'd' ? 1 : 0);
        return path;
    }

    public Compiler(Modules modules)
    {
        this.modules = modules;
        this.bindingTable = modules.BindingTable;
    }

    // A lambda bound by letrec/letrec* to a variable that is never set!:
    // inside its body the variable is the running closure, so a tail call
    // of it with the right argument count becomes LOOP (new frame + jump).
    private sealed class SelfCall
    {
        public readonly object frame; public readonly int index; public readonly int nparams; public readonly string label;
        public SelfCall(object frame, int index, int nparams, string label)
        {
            this.frame = frame; this.index = index; this.nparams = nparams; this.label = label;
        }
    }
    // set before compiling a letrec init that is a lambda; CompLambda takes it
    private SelfCall? pendingSelf;
    // the self call of the function whose body is being compiled, or null
    private SelfCall? currentSelf;
    // counts the CompLambda nesting, so that a loop jumps only within its function
    private int fnLevel;

    // A named let compiled as a loop (CompLoop): the frame of its name.
    private sealed class LoopInfo
    {
        public readonly int nparams; public readonly string label; public readonly int owner;
        public LoopInfo(int nparams, string label, int owner)
        {
            this.nparams = nparams; this.label = label; this.owner = owner;
        }
    }
    private readonly Dictionary<object, LoopInfo> loops = new(ReferenceEqualityComparer.Instance);

    // A loop's name is used other than the prescan allowed: compile the
    // named let the ordinary way instead.
    private sealed class LoopBailout : Exception
    {
        public readonly object frame;
        public LoopBailout(object frame) { this.frame = frame; }
    }

    private static object FrameAt(object env, int depth)
    {
        for (int i = 0; i < depth; i++) env = Value.AsPair(env).cdr;
        return Value.AsPair(env).car;
    }

    /// <summary>The name of the core form x is, or null (function calls, non-pairs).</summary>
    private string? CoreFormName(object x)
    {
        if (!Value.IsPair(x)) return null;
        object head = Value.AsPair(x).car;
        if (head is SyntaxObject stx && stx.IsIdentifier)
        {
            var b = SyntaxObject.Resolve(stx, bindingTable);
            if (b != null && b.BindingKind == ResolvedBinding.Kind.CoreForm) return b.SymbolName;
        }
        return null;
    }

    private static bool IsIdentifier(object x)
    {
        return (x is SyntaxObject stx && stx.IsIdentifier) || Value.IsSymbol(x);
    }

    /// <summary>Whether an identifier called name occurs in code x (quoted data aside).</summary>
    private bool Mentions(object x, string name)
    {
        while (true)
        {
            if (IsIdentifier(x)) return name == GetIdName(x);
            if (!Value.IsPair(x)) return false;
            if (CoreFormName(x) == "quote") return false;
            if (Mentions(Value.AsPair(x).car, name)) return true;
            x = Value.AsPair(x).cdr;
        }
    }

    /// <summary>Whether a set! of an identifier called name occurs in code x.</summary>
    private bool SetsName(object x, string name)
    {
        while (true)
        {
            if (!Value.IsPair(x)) return false;
            string? core = CoreFormName(x);
            if (core == "quote") return false;
            if (core == "set!" && Value.IsPair(Value.AsPair(x).cdr)
                && name == GetIdName(Value.AsPair(x).Second()))
                return true;
            if (SetsName(Value.AsPair(x).car, name)) return true;
            x = Value.AsPair(x).cdr;
        }
    }

    /// <summary>
    /// Whether the named-let name occurs in x only as the operator of calls
    /// with n arguments in tail position of the loop body (tail: x's value is
    /// the body's). Decided by name, so shadowing and macro-renamed
    /// identifiers make it fail rather than slip through.
    /// </summary>
    private bool OnlyLoopCalls(object x, string name, int n, bool tail)
    {
        if (!tail) return !Mentions(x, name);
        if (IsIdentifier(x)) return name != GetIdName(x);
        if (!Value.IsPair(x)) return true;
        Pair p = Value.AsPair(x);
        string? core = CoreFormName(x);
        if (core == null)
        {
            object f = p.car;
            if (IsIdentifier(f) && name == GetIdName(f))
            {
                int argc = 0;
                for (object a = p.cdr; a != Value.NIL; a = Value.AsPair(a).cdr)
                {
                    if (!Value.IsPair(a)) return false;
                    argc++;
                }
                return argc == n && !Mentions(p.cdr, name);
            }
            return !Mentions(x, name);
        }
        switch (core)
        {
            case "quote":
                return true;
            case "begin":
                return BodyOnlyLoopCalls(p.cdr, name, n);
            case "if":
            {
                object rest = p.cdr;
                if (!Value.IsPair(rest) || Mentions(Value.AsPair(rest).car, name)) return false;
                rest = Value.AsPair(rest).cdr;
                while (rest != Value.NIL)
                {
                    if (!Value.IsPair(rest) || !OnlyLoopCalls(Value.AsPair(rest).car, name, n, true)) return false;
                    rest = Value.AsPair(rest).cdr;
                }
                return true;
            }
            case "let": case "let*": case "letrec": case "letrec*":
            {
                if (!Value.IsPair(p.cdr)) return false;
                object bindings = p.Second();
                if (!Value.IsPair(bindings) && bindings != Value.NIL) return false; // named let
                for (object b = bindings; b != Value.NIL; b = Value.AsPair(b).cdr)
                {
                    if (!Value.IsPair(b) || !Value.IsPair(Value.AsPair(b).car)) return false;
                    Pair binding = Value.AsPair(Value.AsPair(b).car);
                    if (name == GetIdName(binding.car) || Mentions(binding.cdr, name)) return false;
                }
                return BodyOnlyLoopCalls(p.NthCdr(2), name, n);
            }
            default:
                return !Mentions(x, name);
        }
    }

    private bool BodyOnlyLoopCalls(object body, string name, int n)
    {
        while (body != Value.NIL)
        {
            if (!Value.IsPair(body)) return false;
            Pair p = Value.AsPair(body);
            if (!OnlyLoopCalls(p.car, name, n, p.cdr == Value.NIL)) return false;
            body = p.cdr;
        }
        return true;
    }

    /// <summary>
    /// Create a SyntaxObject for a core form keyword with the current module scope,
    /// so it resolves through the binding table (mirrors Expander.CoreFormId).
    /// </summary>
    private object CoreFormId(string name)
    {
        int moduleScope = modules.GetCurrentModuleScope();
        return new SyntaxObject(Value.Intern(name), ScopeSet.Of(moduleScope), null);
    }

    /// <summary>Extract identifier name from a SyntaxObject or plain symbol.</summary>
    private static string GetIdName(object x)
    {
        if (x is SyntaxObject stx && stx.IsIdentifier) return stx.SymbolName;
        if (Value.IsSymbol(x)) return Value.AsSymbol(x);
        return null!;
    }

    /// <summary>
    /// Compare two identifiers for binding equivalence.
    /// Two SyntaxObjects match via BoundIdEq (same name + same marks).
    /// Plain symbols match by name. Mixed: compare by name.
    /// </summary>
    private static bool IdentifiersMatch(object a, object b)
    {
        if (a is SyntaxObject sa && sa.IsIdentifier && b is SyntaxObject sb && sb.IsIdentifier)
            return sa.SymbolName == sb.SymbolName && sb.Scopes.IsSubsetOf(sa.Scopes);
        string na = GetIdName(a);
        string nb = GetIdName(b);
        return na != null && na == nb;
    }

    /// <summary>Search a frame for an identifier. Returns index or Value.F.</summary>
    private object InFrameP(object identifier, object frame)
    {
        if (frame == Value.NIL) return Value.F;
        if (IdentifiersMatch(identifier, Value.AsPair(frame).car)) return 0;
        object p = InFrameP(identifier, Value.AsPair(frame).cdr);
        if (!p.Equals(Value.F)) return 1 + (int) p;
        return Value.F;
    }

    /// <summary>Search the env for an identifier. Returns (frame, index) or Value.F.</summary>
    private object InEnvP(object identifier, object env)
    {
        if (env == Value.NIL) return Value.F;
        object f = InFrameP(identifier, Value.AsPair(env).car);
        if (!f.Equals(Value.F)) return Pair.List(0, f);
        object e = InEnvP(identifier, Value.AsPair(env).cdr);
        if (!e.Equals(Value.F)) return Pair.List(1 + (int) Value.AsPair(e).First(), Value.AsPair(e).Second());
        return Value.F;
    }

    private object Gen(SourcePos? pos, Opcode opcode, params object[] args)
    {
        return ((Pair)Pair.List(Pair.List2(opcode, args).WithPos(pos))).WithPos(pos);
    }

    private object Seq(SourcePos? pos, params object[] lists)
    {
        List<object> result = new();
        for (int i = 0; i < lists.Length; i++)
        {
            Pair.AppendToList(lists[i], result);
        }
        object r = Pair.List(result.ToArray());
        return r is Pair rp ? rp.WithPos(pos) : r;
    }

    private int labelNum = 1;

    private string GenLabel()
    {
        return GenLabel("L");
    }

    private string GenLabel(string prefix)
    {
        return prefix + labelNum++;
    }

    /// <summary>
    /// The (frame var) of a local identifier, directly or through the binding
    /// table (cross-scope references), or #f.
    /// </summary>
    private object ResolveLocal(object identifier, object env)
    {
        object p = InEnvP(identifier, env);
        if (!p.Equals(Value.F)) return p;
        if (identifier is SyntaxObject idStx)
        {
            var binding = SyntaxObject.Resolve(idStx, bindingTable);
            if (binding != null && binding.BindingKind == ResolvedBinding.Kind.Local && binding.Value is SyntaxObject bindingVar)
                return InEnvP(bindingVar, env);
        }
        return Value.F;
    }

    // A reference to a loop's name other than a loop call
    private void CheckNotLoop(object p, object env)
    {
        if (loops.Count == 0) return;
        object frame = FrameAt(env, (int) Value.AsPair(p).First());
        if (loops.ContainsKey(frame)) throw new LoopBailout(frame);
    }

    /// <summary>Generate variable access for any identifier (SyntaxObject or plain symbol).</summary>
    private object GenVar(SourcePos? pos, object identifier, object env)
    {
        string name = GetIdName(identifier);
        object p = ResolveLocal(identifier, env);
        if (!p.Equals(Value.F))
        {
            CheckNotLoop(p, env);
            return Gen(pos, Opcode.LVAR, Value.AsPair(p).First(), Value.AsPair(p).Second(), ";", name);
        }
        // Not local → resolve through binding table or fall back to current module
        if (identifier is SyntaxObject idStx)
        {
            var binding = SyntaxObject.Resolve(idStx, bindingTable);
            if (binding != null && binding.ModuleName != null)
                return Gen(pos, Opcode.GVAR, binding.SymbolName, binding.ModuleName);
        }
        return Gen(pos, Opcode.GVAR, name ?? "?", modules.GetCurrentModule().Name);
    }

    /// <summary>Generate variable set for any identifier.</summary>
    private object GenSet(SourcePos? pos, object identifier, object env)
    {
        string name = GetIdName(identifier);
        object p = ResolveLocal(identifier, env);
        if (!p.Equals(Value.F))
        {
            CheckNotLoop(p, env);
            return Gen(pos, Opcode.LSET, Value.AsPair(p).First(), Value.AsPair(p).Second(), ";", name);
        }
        if (identifier is SyntaxObject idStx)
        {
            var binding = SyntaxObject.Resolve(idStx, bindingTable);
            if (binding != null && binding.ModuleName != null)
                return Gen(pos, Opcode.GSET, binding.SymbolName, binding.ModuleName);
        }
        return Gen(pos, Opcode.GSET, name ?? "?", modules.GetCurrentModule().Name);
    }

    /// <summary>
    private object Comp(SourcePos? pos, object x, object env, bool val, bool more) {
        // In the sets-of-scopes model, SyntaxObjects only wrap identifiers.
        // If we see a SyntaxObject, it's always an identifier reference.
        if (x is SyntaxObject stx)
        {
            pos = stx.Pos ?? pos;
            if (stx.IsIdentifier)
            {
                return CompVar(pos, stx, env, val, more);
            }
            // Non-identifier SyntaxObject should not occur in sets-of-scopes model,
            // but handle gracefully by stripping
            x = SyntaxObject.Strip(stx);
        }
        if (x == null) return CompConst(pos, Value.F, val, more); // null treated as unspecified
        if (x.Equals(Value.T) || x.Equals(Value.F)) return CompConst(pos, x, val, more);
        if (Value.IsSymbol(x)) return CompVar(pos, Value.AsSymbol(x), env, val, more);
        if (Value.IsAtom(x)) return CompConst(pos, x, val, more);
        if (Value.IsVector(x)) return CompConst(pos, SyntaxObject.Strip(x), val, more);
        if (Value.IsValues(x)) return CompConst(pos, x, val, more);
        if (x == Value.NIL) return CompConst(pos, Value.NIL, val, more);
        pos = Value.AsPair(x).pos ?? pos;
        object first = Value.AsPair(x).First();
        // Keep the original first element (may be SyntaxObject) for CompFuncall
        object firstOriginal = first;
        // Resolve the head to determine if it's a core form or a variable reference.
        // The Expander emits core forms as SyntaxObjects that resolve to CoreForm bindings.
        // If the head resolves to a CoreForm, dispatch to the core form handler.
        // Otherwise (variable reference, unresolved), compile as a function call.
        string firstStr = "";
        if (first is SyntaxObject firstStx && firstStx.IsIdentifier)
        {
            var binding = SyntaxObject.Resolve(firstStx, bindingTable);
            if (binding != null && binding.BindingKind == ResolvedBinding.Kind.CoreForm)
                firstStr = binding.SymbolName;
            else
                return CompFuncall(Value.AsPair(x).pos ?? pos, firstOriginal, Value.AsPair(x).cdr, env, val, more);
        }
        else if (Value.IsSymbol(first))
        {
            throw new SchemeError(pos, "compiler: unexpected plain symbol in head position: ~a", first);
        }
        if (firstStr.Equals("quote"))
        {
            object quotedDatum = SyntaxObject.Strip(Value.AsPair(x).Second());
            return CompConst(pos, quotedDatum, val, more);
        }
        if (firstStr.Equals("begin")) return CompBegin(pos, Value.AsPair(x).cdr, env, val, more);
        if (firstStr.Equals("define"))
        {
            // (define name value) → (begin (set! name value) 'name)
            // (define (name args...) body...) → (define name (lambda (args...) body...))
            object second = Value.AsPair(x).Second();
            // In sets-of-scopes, SyntaxObjects only wrap identifiers, so second
            // is either a SyntaxObject identifier or a plain Pair
            object secondExposed = second;
            if (Value.IsPair(secondExposed))
            {
                // (define (name args...) body...) → rewrite as (define name (lambda (args...) body...))
                object nameId = Value.AsPair(secondExposed).First();
                object args = Value.AsPair(secondExposed).cdr;
                object body = Value.AsPair(x).NthCdr(2);
                var lambda = new Pair(CoreFormId("lambda"), new Pair(args, body));
                var rewritten = Pair.List(CoreFormId("define"), nameId, lambda);
                return Comp(pos, rewritten, env, val, more);
            }
            else
            {
                // (define name value) → (begin (set! name value) 'name)
                object value = Value.AsPair(x).Third();
                var setForm = Pair.List(CoreFormId("set!"), secondExposed, value);
                var result = Pair.List(CoreFormId("begin"), setForm, Pair.List(CoreFormId("quote"), SyntaxObject.Strip(secondExposed)));
                return Comp(pos, result, env, val, more);
            }
        }
        if (firstStr.Equals("set!"))
        {
            object setVar = Value.AsPair(x).Second();
            // Unwrap SyntaxObject wrapper on the variable
            if (setVar is SyntaxObject setStx && setStx.IsIdentifier)
            {
                // Keep as SyntaxObject — GenSet handles it
            }
            else if (!Value.IsSymbol(setVar))
                throw new SchemeError(pos, "set!: variable must be a symbol, got ~a", setVar);
            return Seq(
                pos,
                Comp(pos, Value.AsPair(x).Third(), env, true, true),
                GenSet(pos, setVar, env),
                val ? (object)Value.NIL : Gen(pos, Opcode.POP),
                more ? (object)Value.NIL : Gen(pos, Opcode.RETURN));
        }
        if (firstStr.Equals("if"))
        {
            if (Value.AsPair(x).Length() == 4)
            {
                return CompIf(
                    pos,
                    Value.AsPair(x).Second(),
                    Value.AsPair(x).Third(),
                    Value.AsPair(x).Fourth(),
                    env, val, more
                );
            }
            else
            {
                return CompIf(
                    pos,
                    Value.AsPair(x).Second(),
                    Value.AsPair(x).Third(),
                    new Values(),
                    env, val, more
                );
            }
        }
        if (firstStr.Equals("lambda"))
        {
            if (!val) return (object)Value.NIL;
            // Internal definitions are handled by the Expander (ExpandBody → letrec*)
            Pair f = CompLambda(
                Value.AsPair(x).pos,
                Value.AsPair(x).Second(),
                Value.AsPair(x).NthCdr(2),
                env
            );
            return Seq(
                pos,
                Gen(pos, Opcode.FN, f),
                more ? (object)Value.NIL : Gen(pos, Opcode.RETURN)
            );
        }
        if (firstStr.Equals("let"))
        {
            return CompLet(pos, x, env, val, more);
        }
        if (firstStr.Equals("let*"))
        {
            return CompLetStar(pos, x, env, val, more);
        }
        if (firstStr.Equals("letrec"))
        {
            return CompLetrec(pos, x, env, val, more);
        }
        if (firstStr.Equals("letrec*"))
        {
            return CompLetrecStar(pos, x, env, val, more);
        }
        return CompFuncall(Value.AsPair(x).pos ?? pos, firstOriginal, Value.AsPair(x).cdr, env, val, more);
    }

    private object CompBegin(SourcePos? pos, object exps, object env, bool val, bool more)
    {
        if (exps == Value.NIL) return CompConst(pos, Value.NIL, val, more);
        if (!Value.IsPair(exps))
            throw new SchemeError(pos, "improper list in begin");

        // All macros and define-syntax are handled by the Expander.
        // The Compiler just compiles the expanded forms sequentially.
        object firstForm = Value.AsPair(exps).First();

        if (Value.AsPair(exps).cdr == Value.NIL)
        {
            return Comp(pos, firstForm, env, val, more);
        }
        return Seq(
            pos,
            Comp(pos, firstForm, env, false, true),
            CompBegin(pos, Value.AsPair(exps).cdr, env, val, more)
        );
    }

    private object CompList(SourcePos? pos, object exps, object env)
    {
        if (exps == Value.NIL) return Value.NIL;
        if (!Value.IsPair(exps))
            throw new SchemeError(pos, "improper list in function call");
        return Seq(
            pos,
            Comp(
                pos,
                Value.AsPair(exps).First(),
                env, true, true
            ),
            CompList(
                pos,
                Value.AsPair(exps).cdr,
                env
            )
        );
    }

    private object CompConst(SourcePos? pos, object x, bool val, bool more)
    {
        if (val) {
            return Seq(
                pos,
                Gen(pos, Opcode.CONST, x),
                more ? (object)Value.NIL : Gen(pos, Opcode.RETURN));
        } else {
            return Value.NIL;
        }
    }

    /// <summary>Compile a variable reference from any identifier type.</summary>
    private object CompVar(SourcePos? pos, object identifier, object env, bool val, bool more)
    {
        if (val)
        {
            return Seq(
                pos,
                GenVar(pos, identifier, env),
                more ? (object)Value.NIL : Gen(pos, Opcode.RETURN)
            );
        }
        else
        {
            return Value.NIL;
        }
    }

    private object CompIf(SourcePos? pos, object pred, object then, object alternative,
                        object env, bool val, bool more)
    {
        if (pred.Equals(Value.F)) return Comp(pos, alternative, env, val, more);
        if (Value.IsConstant(pred)) return Comp(pos, then, env, val, more);
        object pcode = Comp(pos, pred, env, true, true);
        object tcode = Comp(pos, then, env, val, more);
        object ecode = Comp(pos, alternative, env, val, more);
        // Case A: both branches empty — only evaluate predicate for side effects
        if (tcode == Value.NIL && ecode == Value.NIL)
            return Comp(pos, pred, env, false, more);
        // Case B: then-branch empty — use TJUMP to skip over else
        if (tcode == Value.NIL) {
            string l2 = GenLabel();
            return Seq(pos, pcode, Gen(pos, Opcode.TJUMP, l2), ecode, Pair.List(l2),
                       more ? (object)Value.NIL : Gen(pos, Opcode.RETURN));
        }
        // Case C: else-branch empty — use FJUMP to skip over then
        if (ecode == Value.NIL) {
            string l1 = GenLabel();
            return Seq(pos, pcode, Gen(pos, Opcode.FJUMP, l1), tcode, Pair.List(l1),
                       more ? (object)Value.NIL : Gen(pos, Opcode.RETURN));
        }
        // Generic case
        string gl1 = GenLabel();
        string? gl2 = more ? GenLabel() : null;
        return Seq(
            pos,
            pcode,
            Gen(pos, Opcode.FJUMP, gl1),
            tcode,
            more ? Gen(pos, Opcode.JUMP, gl2!) : (object)Value.NIL,
            Pair.List(gl1),
            ecode,
            more ? (object)Pair.List(gl2!) : (object)Value.NIL
        );
    }

    private object CompFuncall(SourcePos? pos, object f, object args,
                             object env, bool val, bool more)
    {
        string fName = GetIdName(f);

        if (Value.IsPair(f))
        {
            object fHead = Value.AsPair(f).First();
            string fHeadName = GetIdName(fHead) ?? (Value.IsSymbol(fHead) ? Value.AsSymbol(fHead) : "");
            object fParams = Value.AsPair(f).cdr != Value.NIL ? Value.AsPair(f).Second() : Value.NIL;
            if (fHeadName == "lambda" && fParams == Value.NIL)
            {
                // ((lambda () body)) ==> (begin body)
                return CompBegin(pos, Value.AsPair(f).NthCdr(2), env, val, more);
            }
            // ((lambda (x y ...) body) a b ...) ==> inline with EXTEND
            if (fHeadName == "lambda"
                && fParams != Value.NIL
                && IsSimpleParamList(fParams))
            {
                int paramCount = Value.AsPair(fParams).Length();
                int argCount = (args == Value.NIL ? 0 : Value.AsPair(args).Length());
                if (paramCount == argCount)
                {
                    object body = Value.AsPair(f).NthCdr(2);
                    if (body != Value.NIL && Value.IsPair(body)
                        && Value.AsPair(body).cdr != Value.NIL
                        && Value.AsPair(body).car is char[])
                        body = Value.AsPair(body).cdr;
                    object newEnv = new Pair(MakeTrueList(fParams), env);
                    if (more)
                    {
                        return Seq(pos,
                            CompList(pos, args, env),
                            Gen(pos, Opcode.EXTEND, paramCount),
                            CompBegin(pos, body, newEnv, val, true),
                            Gen(pos, Opcode.POPENV));
                    }
                    return Seq(pos,
                        CompList(pos, args, env),
                        Gen(pos, Opcode.EXTEND, paramCount),
                        CompBegin(pos, body, newEnv, true, false));
                }
            }
        }
        // A loop call of a named let compiled by CompLoop, or a self tail call
        if (fName != null && (loops.Count > 0 || (!more && currentSelf != null)))
        {
            object p = ResolveLocal(f, env);
            if (!p.Equals(Value.F))
            {
                int depth = (int) Value.AsPair(p).First(), index = (int) Value.AsPair(p).Second();
                int argc = (args == Value.NIL ? 0 : Value.AsPair(args).Length());
                object frame = FrameAt(env, depth);
                string? label = null;
                if (loops.TryGetValue(frame, out var loop))
                {
                    if (index != 0 || loop.owner != fnLevel || argc != loop.nparams)
                        throw new LoopBailout(frame);
                    label = loop.label;
                }
                else if (!more && currentSelf != null && currentSelf.frame == frame
                         && currentSelf.index == index && currentSelf.nparams == argc)
                {
                    label = currentSelf.label;
                }
                if (label != null)
                    return Seq(pos, CompList(pos, args, env), Gen(pos, Opcode.LOOP, argc, depth, label));
            }
        }
        // Intrinsic: identifier not shadowed locally and still bound to the original primitive
        if (fName != null)
        {
            // For SyntaxObjects, resolve through binding table to find the original binding
            string intrinsicName = fName;
            string? intrinsicModule = null;
            if (f is SyntaxObject fIdStx)
            {
                var binding = SyntaxObject.Resolve(fIdStx, bindingTable);
                if (binding != null && binding.ModuleName != null)
                {
                    intrinsicName = binding.SymbolName;
                    intrinsicModule = binding.ModuleName;
                }
            }
            // Check if the identifier is locally bound (including cross-scope via binding table)
            bool isLocallyBound = !InEnvP(f, env).Equals(Value.F);
            if (!isLocallyBound && f is SyntaxObject fStx2)
            {
                var b = SyntaxObject.Resolve(fStx2, bindingTable);
                isLocallyBound = b != null && b.BindingKind == ResolvedBinding.Kind.Local;
            }
            if (s_intrinsics.TryGetValue(intrinsicName, out var info) && !isLocallyBound)
            {
                // Check the binding still points to a primitive
                bool isPrimitive;
                if (intrinsicModule != null)
                {
                    var mod = modules.GetModule(intrinsicModule);
                    isPrimitive = mod != null && mod.IsBound(intrinsicName)
                        && mod.Resolve(pos, intrinsicName) is Primitive;
                }
                else
                {
                    isPrimitive = !modules.GetCurrentModule().IsBound(fName)
                        || modules.GetCurrentModule().Resolve(pos, fName) is Primitive;
                }
                if (isPrimitive)
                {
                    int argc = (args == Value.NIL ? 0 : Value.AsPair(args).Length());
                    if (info.arity == -1 || argc == info.arity)
                    {
                        object opInstr = info.op == Opcode.CXR
                            ? Gen(pos, info.op, CxrPath(intrinsicName), intrinsicName)
                            : Gen(pos, info.op, argc);
                        if (more)
                        {
                            return Seq(pos,
                                CompList(pos, args, env),
                                opInstr,
                                val ? (object)Value.NIL : Gen(pos, Opcode.POP));
                        }
                        return Seq(pos,
                            CompList(pos, args, env),
                            opInstr,
                            Gen(pos, Opcode.RETURN));
                    }
                }
            }
        }
        if (more)
        {
            // CALLS puts the return address under the arguments itself,
            // and only when f is a lambda (a primitive just returns)
            return Seq(
                pos,
                CompList(pos, args, env),
                Comp(pos, f, env, true, true),
                Gen(pos, Opcode.CALLS, (args == Value.NIL ? 0 : Value.AsPair(args).Length())),
                val ? (object)Value.NIL : Gen(pos, Opcode.POP)
            );
        }
        return Seq(
            pos,
            CompList(pos, args, env),
            Comp(pos, f, env, true, true),
            Gen(pos, Opcode.CALLJ, (args == Value.NIL ? 0 : Value.AsPair(args).Length()))
        );
    }

    private Pair CompLambda(SourcePos? pos, object args, object body, object env)
    {
        // Detect and strip docstring: first form is a string literal and body has more forms
        string? docstring = null;
        if (body != Value.NIL
            && Value.IsPair(body)
            && Value.AsPair(body).cdr != Value.NIL
            && Value.AsPair(body).car is char[] docChars)
        {
            docstring = new string(docChars);
            body = Value.AsPair(body).cdr;
        }

        SelfCall? self = pendingSelf;
        pendingSelf = null;
        SelfCall? outerSelf = currentSelf;
        currentSelf = self;
        fnLevel++;
        object code;
        try
        {
            code = Optimize(
                Seq(
                    pos,
                    GenArgs(pos, args, 0),
                    self != null ? Pair.List(self.label) : Value.NIL,
                    CompBegin(pos, body, new Pair(MakeTrueList(args), env), true, false)
                )
            );
        }
        finally
        {
            currentSelf = outerSelf;
            fnLevel--;
        }

        object[] elements = docstring != null
            ? new object[] { Value.Intern("env:"), env, Value.Intern("args:"), args, Value.Intern("code:"), code, Value.Intern("doc:"), docstring }
            : new object[] { Value.Intern("env:"), env, Value.Intern("args:"), args, Value.Intern("code:"), code };

        return Assemble(((Pair)Pair.List(elements)).WithPos(pos));
    }

    /// <summary>Compile (let ((var val) ...) body ...) and named let.</summary>
    private object CompLet(SourcePos? pos, object x, object env, bool val, bool more)
    {
        object second = Value.AsPair(x).Second();
        // Check for named let: (let name ((var val) ...) body ...)
        string nameStr = GetIdName(second);
        if (nameStr != null && !Value.IsPair(second))
        {
            // Named let: rewrite to ((letrec ((name (lambda (vars...) body...))) name) vals...)
            object bindings = Value.AsPair(x).Third();
            object body = Value.AsPair(x).NthCdr(3);
            var vars = new List<object>();
            var vals = new List<object>();
            ExtractBindings(bindings, vars, vals);
            object varList = Pair.List(vars.ToArray());
            if (IsSimpleParamList(varList) && BodyOnlyLoopCalls(body, nameStr, vars.Count))
            {
                object nameFrame = Pair.List(second);
                try
                {
                    return CompLoop(pos, nameFrame, varList, vals, body, env, val, more);
                }
                catch (LoopBailout b) when (b.frame == nameFrame)
                {
                }
            }
            // Build (lambda (vars...) body...)
            var lambdaParts = new List<object> { CoreFormId("lambda"), varList };
            object cur = body;
            while (cur != Value.NIL && Value.IsPair(cur)) { lambdaParts.Add(Value.AsPair(cur).car); cur = Value.AsPair(cur).cdr; }
            object lambdaForm = Pair.List(lambdaParts.ToArray());
            // Build ((letrec ((name lambda)) name) vals...)
            object letrecForm = Pair.List(CoreFormId("letrec"),
                Pair.List(Pair.List(second, lambdaForm)),
                second);
            object callForm = new Pair(letrecForm, Pair.List(vals.ToArray()));
            return Comp(pos, callForm, env, val, more);
        }
        else
        {
            // Simple let: compile as ((lambda (vars...) body...) vals...)
            object bindings = second;
            object body = Value.AsPair(x).NthCdr(2);
            var vars = new List<object>();
            var vals = new List<object>();
            ExtractBindings(bindings, vars, vals);

            // Inline optimization: use EXTEND instead of creating a closure
            int n = vars.Count;
            object newEnv = new Pair(Pair.List(vars.ToArray()), env);
            if (n == 1 && (val || more))
            {
                object? orCode = CompOrTemp(pos, vals[0], body, newEnv, env, val, more);
                if (orCode != null) return orCode;
            }
            if (more)
            {
                return Seq(pos,
                    CompList(pos, Pair.List(vals.ToArray()), env),
                    Gen(pos, Opcode.EXTEND, n),
                    CompBegin(pos, body, newEnv, val, true),
                    Gen(pos, Opcode.POPENV));
            }
            return Seq(pos,
                CompList(pos, Pair.List(vals.ToArray()), env),
                Gen(pos, Opcode.EXTEND, n),
                CompBegin(pos, body, newEnv, true, false));
        }
    }

    /// <summary>
    /// A named let whose name is only called in tail position of its body
    /// (BodyOnlyLoopCalls) as a loop: no closure and no call, each loop call
    /// binds a new frame of the variables and jumps back. The frame of the
    /// name stays (holding #f) so that the body's variable indexes are those
    /// of the ordinary letrec rewrite.
    /// </summary>
    private object CompLoop(SourcePos? pos, object nameFrame, object varList, List<object> vals,
                            object body, object env, bool val, bool more)
    {
        int n = vals.Count;
        object bodyEnv = new Pair(varList, new Pair(nameFrame, env));
        string top = GenLabel();
        loops[nameFrame] = new LoopInfo(n, top, fnLevel);
        try
        {
            object start = Seq(pos,
                CompList(pos, Pair.List(vals.ToArray()), env),
                Gen(pos, Opcode.CONST, Value.F),
                Gen(pos, Opcode.EXTEND, 1),
                Gen(pos, Opcode.EXTEND, n),
                Pair.List(top));
            if (more)
            {
                return Seq(pos, start,
                    CompBegin(pos, body, bodyEnv, val, true),
                    Gen(pos, Opcode.POPENV),
                    Gen(pos, Opcode.POPENV));
            }
            return Seq(pos, start, CompBegin(pos, body, bodyEnv, true, false));
        }
        finally
        {
            loops.Remove(nameFrame);
        }
    }

    /// <summary>
    /// (let ((t e1)) (if t t e2)) with t not in e2 -- what or expands to --
    /// without the frame: e1 TJUMP_KEEP L e2 L. Null if body is not that.
    /// </summary>
    private object? CompOrTemp(SourcePos? pos, object e1, object body, object newEnv, object env,
                               bool val, bool more)
    {
        if (!Value.IsPair(body) || Value.AsPair(body).cdr != Value.NIL) return null;
        object form = Value.AsPair(body).car;
        if (CoreFormName(form) != "if" || Value.AsPair(form).Length() != 4) return null;
        Pair ifForm = Value.AsPair(form);
        string tName = GetIdName(Value.AsPair(Value.AsPair(newEnv).car).car);
        object test = ifForm.Second(), then = ifForm.Third(), e2 = ifForm.Fourth();
        if (tName == null || !IsIdentifier(test) || !IsIdentifier(then) || Mentions(e2, tName)) return null;
        if (!IsFirstLocal(ResolveLocal(test, newEnv)) || !IsFirstLocal(ResolveLocal(then, newEnv))) return null;
        string l = GenLabel();
        if (!val)
        {
            return Seq(pos,
                Comp(pos, e1, env, true, true),
                Gen(pos, Opcode.TJUMP, l),
                Comp(pos, e2, env, false, true),
                Pair.List(l));
        }
        return Seq(pos,
            Comp(pos, e1, env, true, true),
            Gen(pos, Opcode.TJUMP_KEEP, l),
            Comp(pos, e2, env, true, more),
            Pair.List(l),
            more ? (object)Value.NIL : Gen(pos, Opcode.RETURN));
    }

    private static bool IsFirstLocal(object p)
    {
        return !p.Equals(Value.F) && (int) Value.AsPair(p).First() == 0 && (int) Value.AsPair(p).Second() == 0;
    }

    /// <summary>
    /// The self call of letrec variable index of frame bound to init, when init
    /// is a lambda with a plain parameter list and the letrec form x never
    /// set!s the variable; else null.
    /// </summary>
    private SelfCall? SelfCallFor(object x, object frame, int index, object var, object init)
    {
        if (CoreFormName(init) != "lambda") return null;
        Pair lambda = Value.AsPair(init);
        if (!Value.IsPair(lambda.cdr)) return null;
        object parameters = lambda.Second();
        string name = GetIdName(var);
        if (name == null || !IsSimpleParamList(parameters) || SetsName(x, name)) return null;
        int n = parameters == Value.NIL ? 0 : Value.AsPair(parameters).Length();
        return new SelfCall(frame, index, n, GenLabel());
    }

    /// <summary>Compile (let* ((var val) ...) body ...) as nested lets.</summary>
    private object CompLetStar(SourcePos? pos, object x, object env, bool val, bool more)
    {
        object bindings = Value.AsPair(x).Second();
        object body = Value.AsPair(x).NthCdr(2);

        if (bindings == Value.NIL)
        {
            // (let* () body...) = (begin body...)
            return CompBegin(pos, body, env, val, more);
        }

        // Compile first binding, then recurse
        object firstBinding = Value.AsPair(bindings).car;
        object var = Value.AsPair(firstBinding).car;
        object varCdr = Value.AsPair(firstBinding).cdr;
        object valExpr = Value.IsPair(varCdr) ? Value.AsPair(varCdr).car : Value.F;
        object restBindings = Value.AsPair(bindings).cdr;

        // Build inner let*
        var innerParts = new List<object> { CoreFormId("let*"), restBindings };
        object cur = body;
        while (cur != Value.NIL && Value.IsPair(cur)) { innerParts.Add(Value.AsPair(cur).car); cur = Value.AsPair(cur).cdr; }

        // Compile as (let ((var val)) (let* rest body))
        object newEnv = new Pair(Pair.List(var), env);
        if (more)
        {
            return Seq(pos,
                Comp(pos, valExpr, env, true, true),
                Gen(pos, Opcode.EXTEND, 1),
                Comp(pos, Pair.List(innerParts.ToArray()), newEnv, val, true),
                Gen(pos, Opcode.POPENV));
        }
        return Seq(pos,
            Comp(pos, valExpr, env, true, true),
            Gen(pos, Opcode.EXTEND, 1),
            Comp(pos, Pair.List(innerParts.ToArray()), newEnv, true, false));
    }

    /// <summary>Compile (letrec/letrec* ((var val) ...) body ...)</summary>
    /// <summary>
    /// Compile (letrec ((var val) ...) body ...).
    /// R7RS 4.2.2: evaluate ALL init expressions first, then assign all results.
    /// </summary>
    private object CompLetrec(SourcePos? pos, object x, object env, bool val, bool more)
    {
        object bindings = Value.AsPair(x).Second();
        object body = Value.AsPair(x).NthCdr(2);

        var vars = new List<object>();
        var valExprs = new List<object>();
        ExtractBindings(bindings, vars, valExprs);

        int n = vars.Count;
        if (n == 0)
            return CompBegin(pos, body, env, val, more);

        object newEnv = new Pair(Pair.List(vars.ToArray()), env);

        // Push #f placeholders, EXTEND to create the frame
        object initCode = Value.NIL;
        for (int i = 0; i < n; i++)
            initCode = Seq(pos, initCode, Gen(pos, Opcode.CONST, Value.F));
        initCode = Seq(pos, initCode, Gen(pos, Opcode.EXTEND, n));

        // Evaluate ALL init expressions onto the stack
        object evalCode = Value.NIL;
        object frame = Value.AsPair(newEnv).car;
        for (int i = 0; i < n; i++)
        {
            pendingSelf = SelfCallFor(x, frame, i, vars[i], valExprs[i]);
            try
            {
                evalCode = Seq(pos, evalCode,
                    Comp(pos, valExprs[i], newEnv, true, true));
            }
            finally
            {
                pendingSelf = null;
            }
        }

        // Assign all at once in reverse order (last value is on top of stack)
        object setCode = Value.NIL;
        for (int i = n - 1; i >= 0; i--)
        {
            setCode = Seq(pos, setCode,
                Gen(pos, Opcode.LSET, 0, i, ";", GetIdName(vars[i]) ?? "?"),
                Gen(pos, Opcode.POP));
        }

        if (more)
        {
            return Seq(pos,
                initCode, evalCode, setCode,
                CompBegin(pos, body, newEnv, val, true),
                Gen(pos, Opcode.POPENV));
        }
        return Seq(pos,
            initCode, evalCode, setCode,
            CompBegin(pos, body, newEnv, true, false));
    }

    /// <summary>
    /// Compile (letrec* ((var val) ...) body ...).
    /// R7RS 4.2.2: evaluate and assign sequentially left-to-right.
    /// </summary>
    private object CompLetrecStar(SourcePos? pos, object x, object env, bool val, bool more)
    {
        object bindings = Value.AsPair(x).Second();
        object body = Value.AsPair(x).NthCdr(2);

        var vars = new List<object>();
        var valExprs = new List<object>();
        ExtractBindings(bindings, vars, valExprs);

        int n = vars.Count;
        if (n == 0)
            return CompBegin(pos, body, env, val, more);

        object newEnv = new Pair(Pair.List(vars.ToArray()), env);

        // Push #f placeholders, EXTEND to create the frame
        object initCode = Value.NIL;
        for (int i = 0; i < n; i++)
            initCode = Seq(pos, initCode, Gen(pos, Opcode.CONST, Value.F));
        initCode = Seq(pos, initCode, Gen(pos, Opcode.EXTEND, n));

        // Evaluate and assign each binding sequentially
        object setCode = Value.NIL;
        object frame = Value.AsPair(newEnv).car;
        for (int i = 0; i < n; i++)
        {
            pendingSelf = SelfCallFor(x, frame, i, vars[i], valExprs[i]);
            object valCode;
            try
            {
                valCode = Comp(pos, valExprs[i], newEnv, true, true);
            }
            finally
            {
                pendingSelf = null;
            }
            setCode = Seq(pos, setCode,
                valCode,
                Gen(pos, Opcode.LSET, 0, i, ";", GetIdName(vars[i]) ?? "?"),
                Gen(pos, Opcode.POP));
        }

        if (more)
        {
            return Seq(pos,
                initCode, setCode,
                CompBegin(pos, body, newEnv, val, true),
                Gen(pos, Opcode.POPENV));
        }
        return Seq(pos,
            initCode, setCode,
            CompBegin(pos, body, newEnv, true, false));
    }

    /// <summary>Extract vars and vals from a binding list ((var val) ...).</summary>
    private void ExtractBindings(object bindings, List<object> vars, List<object> vals)
    {
        object cur = bindings;
        while (cur != Value.NIL && Value.IsPair(cur))
        {
            object binding = Value.AsPair(cur).car;
            if (Value.IsPair(binding))
            {
                vars.Add(Value.AsPair(binding).car);
                object bindCdr = Value.AsPair(binding).cdr;
                vals.Add(Value.IsPair(bindCdr) ? Value.AsPair(bindCdr).car : Value.F);
            }
            cur = Value.AsPair(cur).cdr;
        }
    }

    private object GenArgs(SourcePos? pos, object args, int nsofar)
    {
        // SyntaxObject identifier = rest parameter
        if (args is SyntaxObject sArgs)
        {
            if (sArgs.IsIdentifier) return Gen(pos, Opcode.ARGSDOT, nsofar);
            // Non-identifier SyntaxObject should not occur; treat as rest param
            return Gen(pos, Opcode.ARGSDOT, nsofar);
        }
        if (args == Value.NIL) return Gen(pos, Opcode.ARGS, nsofar);
        if (Value.IsSymbol(args))
            return Gen(pos, Opcode.ARGSDOT, nsofar);
        if (Value.IsPair(args))
        {
            object first = Value.AsPair(args).First();
            if (Value.IsSymbol(first) || (first is SyntaxObject sParam && sParam.IsIdentifier))
                return GenArgs(pos, Value.AsPair(args).cdr, 1 + nsofar);
        }
        throw new SchemeError(pos, "Illegal argument list");
    }

    private object MakeTrueList(object dottedList)
    {
        // SyntaxObject identifier = rest parameter
        if (dottedList is SyntaxObject sDl)
        {
            if (sDl.IsIdentifier) return Pair.List(dottedList); // rest param
            // Non-identifier SyntaxObject should not occur; treat as atom
            return Pair.List(dottedList);
        }
        if (dottedList == Value.NIL) return Value.NIL;
        if (Value.IsAtom(dottedList)) return Pair.List(dottedList);
        if (Value.IsPair(dottedList))
            return new Pair(
                Value.AsPair(dottedList).First(),
                MakeTrueList(Value.AsPair(dottedList).cdr)
            );
        return Pair.List(dottedList);
    }

    private static bool IsSimpleParamList(object paramList)
    {
        object cur = paramList;
        while (cur != Value.NIL)
        {
            if (cur is SyntaxObject sId && sId.IsIdentifier) return false; // rest param
            if (!Value.IsPair(cur)) return false; // dotted/rest param
            object param = Value.AsPair(cur).car;
            if (!Value.IsSymbol(param) && !(param is SyntaxObject sp && sp.IsIdentifier))
                return false;
            cur = Value.AsPair(cur).cdr;
        }
        return true;
    }

    private object Optimize(object code) {
        var items = new List<object>();
        object cur = code;
        while (cur != Value.NIL) { items.Add(Value.AsPair(cur).car); cur = Value.AsPair(cur).cdr; }

        bool changed = true;
        while (changed) {
            changed  = PeepholeDeadCode(items);
            changed |= PeepholeUselessJumps(items);
            changed |= PeepholeLoadPop(items);
            changed |= PeepholeJumpToReturn(items);
            changed |= PeepholeNotBranch(items);
            changed |= PeepholeConstBranch(items);
            changed |= PeepholeJumpThread(items);
            changed |= PeepholeUnusedLabels(items);
            changed |= PeepholeLocalAddImm(items);
            changed |= PeepholeKeepBranch(items);
        }
        PeepholeFuse(items);
        return (Pair)Pair.List(items.ToArray());
    }

    private static bool IsInstr(object item) => Value.IsPair(item);
    private static bool IsLabel(object item) => Value.IsSymbol(item);
    private static Opcode GetOp(object item) => (Opcode) Value.AsPair(item).car;
    private static string GetTarget(object item) => (string) Value.AsPair(item).Second();

    // Pass A: Remove dead code after RETURN or JUMP (until next label)
    private static bool PeepholeDeadCode(List<object> items) {
        bool changed = false;
        int i = 0;
        while (i < items.Count) {
            if (IsInstr(items[i]) && (GetOp(items[i]) == Opcode.RETURN || GetOp(items[i]) == Opcode.JUMP
                                      || GetOp(items[i]) == Opcode.LOOP)) {
                int j = i + 1;
                while (j < items.Count && IsInstr(items[j])) {
                    items.RemoveAt(j);
                    changed = true;
                }
            }
            i++;
        }
        return changed;
    }

    // Pass B: Remove or replace jump to immediately-following label
    private static bool PeepholeUselessJumps(List<object> items) {
        bool changed = false;
        for (int i = 0; i < items.Count; i++) {
            if (!IsInstr(items[i])) continue;
            Opcode op = GetOp(items[i]);
            if (op != Opcode.JUMP && op != Opcode.FJUMP && op != Opcode.TJUMP) continue;
            string target = GetTarget(items[i]);
            // Check if the very next item is the target label
            if (i + 1 < items.Count && IsLabel(items[i + 1]) && (string) items[i + 1] == target) {
                if (op == Opcode.JUMP) {
                    items.RemoveAt(i);
                    i--;
                } else {
                    // FJUMP/TJUMP: condition still on stack, replace with POP
                    items[i] = Pair.List((object) Opcode.POP);
                }
                changed = true;
            }
        }
        return changed;
    }

    // Pass C: Remove CONST/LVAR/GVAR immediately followed by POP
    private static bool PeepholeLoadPop(List<object> items) {
        bool changed = false;
        for (int i = 0; i + 1 < items.Count; i++) {
            if (!IsInstr(items[i]) || !IsInstr(items[i + 1])) continue;
            Opcode op = GetOp(items[i]);
            if ((op == Opcode.CONST || op == Opcode.LVAR || op == Opcode.GVAR)
                && GetOp(items[i + 1]) == Opcode.POP) {
                items.RemoveAt(i + 1);
                items.RemoveAt(i);
                i--;
                changed = true;
            }
        }
        return changed;
    }

    // Pass D: Replace JUMP L with RETURN when L leads to RETURN
    private static bool PeepholeJumpToReturn(List<object> items) {
        bool changed = false;
        for (int i = 0; i < items.Count; i++) {
            if (!IsInstr(items[i]) || GetOp(items[i]) != Opcode.JUMP) continue;
            string target = GetTarget(items[i]);
            // Find target label index
            int labelIdx = -1;
            for (int j = 0; j < items.Count; j++) {
                if (IsLabel(items[j]) && (string) items[j] == target) { labelIdx = j; break; }
            }
            if (labelIdx < 0) continue;
            // Skip adjacent labels to find next instruction
            int k = labelIdx + 1;
            while (k < items.Count && IsLabel(items[k])) k++;
            if (k < items.Count && IsInstr(items[k]) && GetOp(items[k]) == Opcode.RETURN) {
                items[i] = Pair.List((object) Opcode.RETURN);
                changed = true;
            }
        }
        return changed;
    }

    // Pass E: Replace NOT + FJUMP/TJUMP with flipped branch
    private static bool PeepholeNotBranch(List<object> items) {
        bool changed = false;
        for (int i = 0; i + 1 < items.Count; i++) {
            if (!IsInstr(items[i]) || !IsInstr(items[i + 1])) continue;
            if (GetOp(items[i]) != Opcode.NOT) continue;
            Opcode next = GetOp(items[i + 1]);
            if (next == Opcode.FJUMP) {
                string label = GetTarget(items[i + 1]);
                items[i] = Pair.List((object) Opcode.TJUMP, label);
                items.RemoveAt(i + 1);
                changed = true;
            } else if (next == Opcode.TJUMP) {
                string label = GetTarget(items[i + 1]);
                items[i] = Pair.List((object) Opcode.FJUMP, label);
                items.RemoveAt(i + 1);
                changed = true;
            }
        }
        return changed;
    }

    // Pass F: Fold CONST + FJUMP/TJUMP into JUMP or remove both
    private static bool PeepholeConstBranch(List<object> items) {
        bool changed = false;
        for (int i = 0; i + 1 < items.Count; i++) {
            if (!IsInstr(items[i]) || !IsInstr(items[i + 1])) continue;
            if (GetOp(items[i]) != Opcode.CONST) continue;
            Opcode next = GetOp(items[i + 1]);
            if (next != Opcode.FJUMP && next != Opcode.TJUMP) continue;
            object constVal = Value.AsPair(items[i]).Second();
            string label = GetTarget(items[i + 1]);
            bool isFalse = constVal.Equals(Value.F);
            bool branchTaken = (next == Opcode.FJUMP) ? isFalse : !isFalse;
            if (branchTaken) {
                // Always taken: replace both with JUMP
                items[i] = Pair.List((object) Opcode.JUMP, label);
                items.RemoveAt(i + 1);
            } else {
                // Never taken: remove both (net stack effect 0)
                items.RemoveAt(i + 1);
                items.RemoveAt(i);
                i--;
            }
            changed = true;
        }
        return changed;
    }

    // Pass G: Thread jumps through intermediate unconditional jumps
    private static bool PeepholeJumpThread(List<object> items) {
        bool changed = false;
        for (int i = 0; i < items.Count; i++) {
            if (!IsInstr(items[i])) continue;
            Opcode op = GetOp(items[i]);
            if (op != Opcode.JUMP && op != Opcode.FJUMP && op != Opcode.TJUMP && op != Opcode.TJUMP_KEEP) continue;
            string target = GetTarget(items[i]);
            // Follow the chain up to 5 hops
            HashSet<string> visited = new() { target };
            string current = target;
            for (int depth = 0; depth < 5; depth++) {
                int labelIdx = -1;
                for (int j = 0; j < items.Count; j++) {
                    if (IsLabel(items[j]) && (string) items[j] == current) { labelIdx = j; break; }
                }
                if (labelIdx < 0) break;
                int k = labelIdx + 1;
                while (k < items.Count && IsLabel(items[k])) k++;
                if (k >= items.Count || !IsInstr(items[k]) || GetOp(items[k]) != Opcode.JUMP) break;
                string next = GetTarget(items[k]);
                if (visited.Contains(next)) break;
                visited.Add(next);
                current = next;
            }
            if (current != target) {
                items[i] = Pair.List((object) op, current);
                changed = true;
            }
        }
        return changed;
    }

    // Pass H: Remove labels not referenced by any jump or save
    private static bool PeepholeUnusedLabels(List<object> items) {
        HashSet<string> referenced = new();
        foreach (object item in items) {
            if (!IsInstr(item)) continue;
            Opcode op = GetOp(item);
            if (op == Opcode.JUMP || op == Opcode.FJUMP || op == Opcode.TJUMP || op == Opcode.SAVE
                || op == Opcode.TJUMP_KEEP) {
                referenced.Add(GetTarget(item));
            } else if (op == Opcode.LOOP) {
                referenced.Add((string) Value.AsPair(item).Fourth());
            }
        }
        bool changed = false;
        for (int i = items.Count - 1; i >= 0; i--) {
            if (IsLabel(items[i]) && !referenced.Contains((string) items[i])) {
                items.RemoveAt(i);
                changed = true;
            }
        }
        return changed;
    }

    // Pass K: a TJUMP_KEEP to a branch on the kept value branches itself:
    // to L: FJUMP M or L: POP -> TJUMP past it; to L: TJUMP/TJUMP_KEEP M -> that
    private bool PeepholeKeepBranch(List<object> items) {
        bool changed = false;
        for (int i = 0; i < items.Count; i++) {
            if (!IsInstr(items[i]) || GetOp(items[i]) != Opcode.TJUMP_KEEP) continue;
            string target = GetTarget(items[i]);
            int labelIdx = -1;
            for (int j = 0; j < items.Count; j++) {
                if (IsLabel(items[j]) && (string) items[j] == target) { labelIdx = j; break; }
            }
            if (labelIdx < 0) continue;
            int k = labelIdx + 1;
            while (k < items.Count && IsLabel(items[k])) k++;
            if (k >= items.Count || !IsInstr(items[k])) continue;
            Opcode next = GetOp(items[k]);
            if (next == Opcode.TJUMP || next == Opcode.TJUMP_KEEP) {
                items[i] = Pair.List((object) next, GetTarget(items[k]));
                changed = true;
            } else if ((next == Opcode.FJUMP || next == Opcode.POP) && k > i) {
                string after;
                if (k + 1 < items.Count && IsLabel(items[k + 1])) {
                    after = (string) items[k + 1];
                } else {
                    after = GenLabel();
                    items.Insert(k + 1, after);
                }
                items[i] = Pair.List((object) Opcode.TJUMP, after);
                changed = true;
            }
        }
        return changed;
    }

    // Pass I: Fuse LVAR + CONST(long) + ADD/SUB 2 → LVAR_ADD_IMM / LVAR_SUB_IMM
    private static bool PeepholeLocalAddImm(List<object> items) {
        bool changed = false;
        for (int i = 0; i + 2 < items.Count; i++) {
            if (!IsInstr(items[i]) || !IsInstr(items[i + 1]) || !IsInstr(items[i + 2])) continue;
            if (GetOp(items[i]) != Opcode.LVAR) continue;
            Pair constInstr = Value.AsPair(items[i + 1]);
            if (GetOp(constInstr) != Opcode.CONST) continue;
            if (constInstr.Second() is not long imm) continue;
            Pair arithInstr = Value.AsPair(items[i + 2]);
            Opcode arithOp = GetOp(arithInstr);
            if (arithOp != Opcode.ADD && arithOp != Opcode.SUB) continue;
            if ((int)arithInstr.Second() != 2) continue;
            Pair lvarInstr = Value.AsPair(items[i]);
            long packed = ((long)(int)lvarInstr.Second() << 16) | (long)(int)lvarInstr.Third();
            Opcode fused = arithOp == Opcode.ADD ? Opcode.LVAR_ADD_IMM : Opcode.LVAR_SUB_IMM;
            items[i] = Pair.List2(fused, new object[] { packed, imm }).WithPos(lvarInstr.pos);
            items.RemoveAt(i + 2);
            items.RemoveAt(i + 1);
            changed = true;
        }
        return changed;
    }

    // Pass J: Fuse frequent instruction sequences into one instruction.
    // Runs once after the other passes, which do not know the fused
    // opcodes (the jump passes would miss their targets).
    private static void PeepholeFuse(List<object> items) {
        for (int i = 0; i + 1 < items.Count; i++) {
            if (!IsInstr(items[i]) || !IsInstr(items[i + 1])) continue;
            Pair a = Value.AsPair(items[i]);
            Pair b = Value.AsPair(items[i + 1]);
            Pair? c = i + 2 < items.Count && IsInstr(items[i + 2]) ? Value.AsPair(items[i + 2]) : null;
            Opcode opA = GetOp(a), opB = GetOp(b);
            Opcode? opC = c != null ? GetOp(c) : null;
            Pair? fused = null;
            int length = 2;
            if (opA == Opcode.GVAR && (opB == Opcode.CALLS || opB == Opcode.CALLJ)) {
                // arg count, module, symbol
                fused = Pair.List2(opB == Opcode.CALLS ? Opcode.GCALLS : Opcode.GCALLJ,
                                   b.Second(), a.Third(), a.Second()).WithPos(b.pos);
            } else if (opA == Opcode.LVAR && (opB == Opcode.CAR || opB == Opcode.CDR)) {
                fused = Pair.List2(opB == Opcode.CAR ? Opcode.LVAR_CAR : Opcode.LVAR_CDR,
                                   a.Second(), a.Third()).WithPos(b.pos);
            } else if (opA == Opcode.LVAR && opB == Opcode.CONST && opC == Opcode.VECTOR_REF
                       && b.Second() is long k && k >= 0 && k <= int.MaxValue) {
                fused = Pair.List2(Opcode.LVAR_VREF, a.Second(), a.Third(), (int)k).WithPos(c!.pos);
                length = 3;
            } else if (opA == Opcode.LVAR && (opB == Opcode.IS_NULL || opB == Opcode.IS_PAIR)
                       && opC == Opcode.FJUMP) {
                fused = Pair.List2(opB == Opcode.IS_NULL ? Opcode.LVAR_NULL_FJUMP : Opcode.LVAR_PAIR_FJUMP,
                                   a.Second(), a.Third(), c!.Second()).WithPos(c.pos);
                length = 3;
            } else if (opA == Opcode.CONST && opB == Opcode.EQ_P && opC == Opcode.FJUMP) {
                fused = Pair.List2(Opcode.CONST_EQ_FJUMP, a.Second(), c!.Second()).WithPos(c.pos);
                length = 3;
            }
            if (fused == null) continue;
            items[i] = fused;
            for (int n = 1; n < length; n++) items.RemoveAt(i + 1);
        }
    }

    private Pair Assemble(Pair fn) {
        object code = fn.Sixth();
        Dictionary<string, int> labels = new();
        List<Instruction> instructions = new CodeList();
        int i = 0;
        while (code != Value.NIL)
        {
            if (Value.IsSymbol(Value.AsPair(code).car))
            {
                labels[Value.AsSymbol(Value.AsPair(code).car)] = i;
            }
            else
            {
                Pair current = Value.AsPair(Value.AsPair(code).car);
                Instruction instr = new Instruction((Opcode) current.First());
                if (current.Length() > 1) instr.arg1 = current.Second();
                if (current.Length() > 2) instr.arg2 = current.Third();
                if (current.Length() > 3 && Instruction.HasArg3(instr.opcode)) instr.arg3 = current.Fourth();
                if (current.pos != null) instr.pos = current.pos;
                instructions.Add(instr);
                i++;
            }
            code = Value.AsPair(code).cdr;
        }
        foreach (Instruction instruction in instructions)
        {
            if (instruction.opcode == Opcode.JUMP
                || instruction.opcode == Opcode.TJUMP
                || instruction.opcode == Opcode.TJUMP_KEEP
                || instruction.opcode == Opcode.FJUMP
                || instruction.opcode == Opcode.SAVE)
            {
                instruction.arg1 = labels[instruction.arg1?.ToString() ?? "?"];
            }
            else if (instruction.opcode == Opcode.CONST_EQ_FJUMP)
            {
                instruction.arg2 = labels[instruction.arg2?.ToString() ?? "?"];
            }
            else if (instruction.opcode == Opcode.LVAR_NULL_FJUMP
                || instruction.opcode == Opcode.LVAR_PAIR_FJUMP
                || instruction.opcode == Opcode.LOOP)
            {
                instruction.arg3 = labels[instruction.arg3?.ToString() ?? "?"];
            }
            instruction.DecodeInts();
        }
        Value.AsPair(fn.NthCdr(5)).car = instructions;
        return fn;
    }

    public Pair Compile(SourcePos? pos, object x) {
        labelNum = 1;
        var expander = new Expander(modules);
        x = expander.Expand(pos, x);
        return (Pair) CompLambda(pos, Value.NIL, Pair.List(x), (object)Value.NIL);
    }

}
