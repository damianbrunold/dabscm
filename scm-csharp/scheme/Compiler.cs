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
    };

    public Compiler(Modules modules)
    {
        this.modules = modules;
        this.bindingTable = modules.BindingTable;
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

    /// <summary>Generate variable access for any identifier (SyntaxObject or plain symbol).</summary>
    private object GenVar(SourcePos? pos, object identifier, object env)
    {
        string name = GetIdName(identifier);
        object p = InEnvP(identifier, env);
        if (!p.Equals(Value.F))
        {
            return Gen(pos, Opcode.LVAR, Value.AsPair(p).First(), Value.AsPair(p).Second(), ";", name);
        }
        // Not local → resolve through binding table or fall back to current module
        if (identifier is SyntaxObject idStx)
        {
            var binding = SyntaxObject.Resolve(idStx, bindingTable);
            if (binding != null && binding.BindingKind == ResolvedBinding.Kind.Local && binding.Value is SyntaxObject bindingVar)
            {
                object p2 = InEnvP(bindingVar, env);
                if (!p2.Equals(Value.F))
                    return Gen(pos, Opcode.LVAR, Value.AsPair(p2).First(), Value.AsPair(p2).Second(), ";", name);
            }

            if (binding != null && binding.ModuleName != null)
                return Gen(pos, Opcode.GVAR, binding.SymbolName, binding.ModuleName);
        }
        return Gen(pos, Opcode.GVAR, name ?? "?", modules.GetCurrentModule().Name);
    }

    /// <summary>Generate variable set for any identifier.</summary>
    private object GenSet(SourcePos? pos, object identifier, object env)
    {
        string name = GetIdName(identifier);
        object p = InEnvP(identifier, env);
        if (!p.Equals(Value.F))
        {
            return Gen(pos, Opcode.LSET, Value.AsPair(p).First(), Value.AsPair(p).Second(), ";", name);
        }
        if (identifier is SyntaxObject idStx)
        {
            var binding = SyntaxObject.Resolve(idStx, bindingTable);
            if (binding != null && binding.BindingKind == ResolvedBinding.Kind.Local && binding.Value is SyntaxObject bindingVar)
            {
                object p2 = InEnvP(bindingVar, env);
                if (!p2.Equals(Value.F))
                    return Gen(pos, Opcode.LSET, Value.AsPair(p2).First(), Value.AsPair(p2).Second(), ";", name);
            }

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
                        string k = GenLabel("K");
                        return Seq(pos,
                            Gen(pos, Opcode.SAVE, k),
                            CompList(pos, args, env),
                            Gen(pos, Opcode.EXTEND, paramCount),
                            CompBegin(pos, body, newEnv, true, false),
                            Pair.List(k),
                            val ? (object)Value.NIL : Gen(pos, Opcode.POP));
                    }
                    return Seq(pos,
                        CompList(pos, args, env),
                        Gen(pos, Opcode.EXTEND, paramCount),
                        CompBegin(pos, body, newEnv, true, false));
                }
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
                        if (more)
                        {
                            return Seq(pos,
                                CompList(pos, args, env),
                                Gen(pos, info.op, argc),
                                val ? (object)Value.NIL : Gen(pos, Opcode.POP));
                        }
                        return Seq(pos,
                            CompList(pos, args, env),
                            Gen(pos, info.op, argc),
                            Gen(pos, Opcode.RETURN));
                    }
                }
            }
        }
        if (more)
        {
            string k = GenLabel("K");
            return Seq(
                pos,
                Gen(pos, Opcode.SAVE, k),
                CompList(pos, args, env),
                Comp(pos, f, env, true, true),
                Gen(pos, Opcode.CALLJ, (args == Value.NIL ? 0 : Value.AsPair(args).Length())),
                Pair.List(k),
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

        object code = Optimize(
            Seq(
                pos,
                GenArgs(pos, args, 0),
                CompBegin(pos, body, new Pair(MakeTrueList(args), env), true, false)
            )
        );

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
            if (more)
            {
                string k = GenLabel("K");
                return Seq(pos,
                    Gen(pos, Opcode.SAVE, k),
                    CompList(pos, Pair.List(vals.ToArray()), env),
                    Gen(pos, Opcode.EXTEND, n),
                    CompBegin(pos, body, newEnv, true, false),
                    Pair.List(k),
                    val ? (object)Value.NIL : Gen(pos, Opcode.POP));
            }
            return Seq(pos,
                CompList(pos, Pair.List(vals.ToArray()), env),
                Gen(pos, Opcode.EXTEND, n),
                CompBegin(pos, body, newEnv, true, false));
        }
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
            string k = GenLabel("K");
            return Seq(pos,
                Gen(pos, Opcode.SAVE, k),
                Comp(pos, valExpr, env, true, true),
                Gen(pos, Opcode.EXTEND, 1),
                Comp(pos, Pair.List(innerParts.ToArray()), newEnv, true, false),
                Pair.List(k),
                val ? (object)Value.NIL : Gen(pos, Opcode.POP));
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
        for (int i = 0; i < n; i++)
        {
            evalCode = Seq(pos, evalCode,
                Comp(pos, valExprs[i], newEnv, true, true));
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
            string k = GenLabel("K");
            return Seq(pos,
                Gen(pos, Opcode.SAVE, k),
                initCode, evalCode, setCode,
                CompBegin(pos, body, newEnv, true, false),
                Pair.List(k),
                val ? (object)Value.NIL : Gen(pos, Opcode.POP));
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
        for (int i = 0; i < n; i++)
        {
            setCode = Seq(pos, setCode,
                Comp(pos, valExprs[i], newEnv, true, true),
                Gen(pos, Opcode.LSET, 0, i, ";", GetIdName(vars[i]) ?? "?"),
                Gen(pos, Opcode.POP));
        }

        if (more)
        {
            string k = GenLabel("K");
            return Seq(pos,
                Gen(pos, Opcode.SAVE, k),
                initCode, setCode,
                CompBegin(pos, body, newEnv, true, false),
                Pair.List(k),
                val ? (object)Value.NIL : Gen(pos, Opcode.POP));
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
        }
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
            if (IsInstr(items[i]) && (GetOp(items[i]) == Opcode.RETURN || GetOp(items[i]) == Opcode.JUMP)) {
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
            if (op != Opcode.JUMP && op != Opcode.FJUMP && op != Opcode.TJUMP) continue;
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
            if (op == Opcode.JUMP || op == Opcode.FJUMP || op == Opcode.TJUMP || op == Opcode.SAVE) {
                referenced.Add(GetTarget(item));
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

    private Pair Assemble(Pair fn) {
        object code = fn.Sixth();
        Dictionary<string, int> labels = new();
        List<Instruction> instructions = new();
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
                || instruction.opcode == Opcode.FJUMP
                || instruction.opcode == Opcode.SAVE)
            {
                instruction.arg1 = labels[instruction.arg1?.ToString() ?? "?"];
            }
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
