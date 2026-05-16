using System.Collections.Generic;
using System.IO;
using System.Text;

namespace scheme;

/// <summary>
/// Sets-of-scopes macro expander (Flatt 2016). Performs a separate expansion
/// pass before compilation.
///
/// The expander:
/// 1. Wraps input S-expressions as syntax objects with module scope
/// 2. Expands all macros using the use-site/intro scope flip protocol
/// 3. Processes define-syntax, let-syntax, letrec-syntax
/// 4. Handles define (both simple and function-shorthand)
/// 5. Handles internal definitions in lambda bodies
/// 6. Resolves all identifiers via sets of scopes + binding table
/// 7. Returns fully-expanded S-expressions with resolved names
///
/// The output contains only core forms: if, lambda, set!, quote, begin, define, applications.
/// The compiler receives this output and produces bytecode without any macro handling.
/// </summary>
public class Expander
{
    private readonly Modules modules;
    private readonly BindingTable bindingTable;

    public Expander(Modules modules)
    {
        this.modules = modules;
        this.bindingTable = modules.BindingTable;
    }

    /// <summary>
    /// Expand a top-level form. Returns fully-expanded S-expression.
    /// </summary>
    public object Expand(SourcePos? pos, object form)
    {
        // Get or create the module scope for the current module
        int moduleScope = modules.GetCurrentModuleScope();

        // Register core form bindings in the binding table
        bindingTable.RegisterCoreFormBindings(moduleScope);

        // Wrap the input as syntax objects with the module scope
        object wrapped = SyntaxObject.WrapDatum(form, ScopeSet.Of(moduleScope), pos);

        // Expand recursively
        object expanded = ExpandForm(pos, wrapped);

        return expanded;
    }

    /// <summary>
    /// Create a SyntaxObject for a core form keyword (lambda, define, etc.)
    /// with the current module scope, so it resolves through the binding table.
    /// </summary>
    private object CoreFormId(string name)
    {
        int moduleScope = modules.GetCurrentModuleScope();
        return new SyntaxObject(Value.Intern(name), ScopeSet.Of(moduleScope), null);
    }

    // ---- Core Expansion ----

    /// <summary>
    /// Recursively expand a form (syntax object or plain datum).
    /// </summary>
    private object ExpandForm(SourcePos? pos, object stx)
    {
        // Self-quoting constants: numbers, booleans, chars, strings, NIL
        if (stx == null || stx == Value.NIL) return stx!;
        if (stx.Equals(Value.T) || stx.Equals(Value.F)) return stx;
        if (Value.IsConstant(stx)) return stx;

        // Identifier (SyntaxObject wrapping a symbol)
        if (stx is SyntaxObject idStx && idStx.IsIdentifier)
        {
            return ExpandIdentifier(pos, idStx);
        }

        // Plain symbol (no scopes)
        if (Value.IsSymbol(stx))
        {
            return stx; // Pass through as-is
        }

        // In sets-of-scopes, pairs are never wrapped in SyntaxObject.
        // Must be a pair (list form) at this point.
        if (!Value.IsPair(stx)) return stx;
        Pair form = Value.AsPair(stx);
        pos = form.pos ?? pos;

        // Get the operator (first element)
        object first = form.car;
        string? resolvedName = null;
        ResolvedBinding? firstBinding = null;

        // Resolve the operator name
        if (first is SyntaxObject firstId && firstId.IsIdentifier)
        {
            firstBinding = SyntaxObject.Resolve(firstId, bindingTable);
            if (firstBinding != null)
            {
                // Dispatch based on binding kind
                if (firstBinding.BindingKind == ResolvedBinding.Kind.CoreForm)
                    return ExpandCoreForm(pos, stx, firstBinding.SymbolName);
                if (firstBinding.BindingKind == ResolvedBinding.Kind.Macro)
                    return ExpandMacroCall(pos, stx, firstBinding.SymbolName, firstBinding.Value!);
            }
            resolvedName = firstBinding?.SymbolName ?? firstId.SymbolName;
        }
        else if (Value.IsSymbol(first))
        {
            resolvedName = Value.AsSymbol(first);
        }

        // Function call: expand all sub-expressions
        return ExpandApplication(pos, stx);
    }

    /// <summary>
    /// Dispatch to the appropriate core form expander.
    /// </summary>
    private object ExpandCoreForm(SourcePos? pos, object stx, string formName)
    {
        switch (formName)
        {
            case "quote":
                return ((Pair)Pair.List(CoreFormId("quote"), SyntaxObject.Strip(FormNth(stx, 1)))).WithPos(pos);

            case "quasiquote":
                return ExpandQuasiquote(pos, FormNth(stx, 1));

            case "if":
                return ExpandIf(pos, stx);

            case "set!":
                return ExpandSet(pos, stx);

            case "begin":
                return ExpandBegin(pos, FormNthCdr(stx, 1));

            case "lambda":
                return ExpandLambda(pos, stx);

            case "define":
                return ExpandDefine(pos, stx);

            case "define-syntax":
                return ExpandDefineSyntax(pos, stx, inBodyContext: false);

            case "let":
                return ExpandLet(pos, stx);

            case "let*":
                return ExpandLetStar(pos, stx);

            case "letrec":
            case "letrec*":
                return ExpandLetrec(pos, stx, formName);

            case "let-syntax":
                return ExpandLetSyntax(pos, stx);

            case "letrec-syntax":
                return ExpandLetrecSyntax(pos, stx);

            case "cond-expand":
                return ExpandCondExpand(pos, stx);

            case "%primitive":
                // Resolve primitive at expansion time
                {
                    object arg = SyntaxObject.Strip(FormNth(stx, 1));
                    // Unwrap (quote x) → x
                    if (Value.IsPair(arg) && Value.IsSymbol(Value.AsPair(arg).car)
                        && Value.AsSymbol(Value.AsPair(arg).car) == "quote")
                        arg = Value.AsPair(arg).Second();
                    string name;
                    if (Value.IsSymbol(arg))
                        name = Value.AsSymbol(arg);
                    else
                        name = new string(Value.AsString(arg));
                    object primitive = modules.primitives.GetPrimitive(pos, name);
                    return ((Pair)Pair.List(CoreFormId("quote"), primitive)).WithPos(pos);
                }

            case "import":
                // (import spec1 spec2 ...) — process each import set at expansion time
                return ExpandImport(pos, stx);

            case "define-library":
                return ExpandDefineLibrary(pos, stx);

            default:
                // Unknown core form — treat as application
                return ExpandApplication(pos, stx);
        }
    }

    // ---- Identifier Resolution ----

    private object ExpandIdentifier(SourcePos? pos, SyntaxObject idStx)
    {
        // R7RS 4.1.1: "It is an error to reference or assign the value of a syntax keyword."
        var binding = SyntaxObject.Resolve(idStx, bindingTable);
        if (binding != null && binding.BindingKind == ResolvedBinding.Kind.CoreForm)
            throw new SchemeError(pos, "syntax keyword '~a' cannot be used as an expression",
                idStx.SymbolName);
        // Return the SyntaxObject as-is — the compiler resolves identifiers
        // through their scope sets using BoundIdEq for local lookups
        // and the binding table for global lookups.
        return idStx;
    }

    // ---- Macro Expansion (Sets-of-Scopes Protocol) ----

    private object ExpandMacroCall(SourcePos? pos, object form, string macroName,
                                   object transformer)
    {
        if (!(transformer is SyntaxRulesTransformer srt))
            throw new SchemeError(pos, "macro ~a: expected syntax-rules transformer", macroName);

        // Sets-of-scopes: use-site scope + intro scope flip
        int useSiteScope = SyntaxObject.FreshScope();
        int introScope = SyntaxObject.FreshScope();

        // Step 1: Add use-site scope and intro scope to input
        object scopedInput = SyntaxObject.AddScope(form, useSiteScope);
        scopedInput = SyntaxObject.AddScope(scopedInput, introScope);

        // Extract args (cdr of scoped input)
        object args;
        if (Value.IsPair(scopedInput))
            args = Value.AsPair(scopedInput).cdr;
        else
            args = Value.NIL;

        // Step 2: Transform
        object result;
        try { result = srt.TransformRaw(args, modules); }
        catch (SchemeError e)
        {
            throw new SchemeError(e, pos, "error in expansion of macro ~a", macroName);
        }

        // Step 3: Flip intro scope on output
        // Input identifiers (passed through template) have introScope, flip removes it.
        // Template identifiers don't have introScope, flip adds it.
        result = SyntaxObject.FlipScope(result, introScope);

        // Step 4: Recurse
        return ExpandForm(pos, result);
    }

    // ---- Core Form Expansion ----

    private object ExpandIf(SourcePos? pos, object form)
    {
        int len = FormLength(form);
        object test = ExpandForm(pos, FormNth(form, 1));
        object then = ExpandForm(pos, FormNth(form, 2));
        object alt = len >= 4 ? ExpandForm(pos, FormNth(form, 3)) : new Values();
        return ((Pair)Pair.List(CoreFormId("if"), test, then, alt)).WithPos(pos);
    }

    private object ExpandSet(SourcePos? pos, object form)
    {
        object var = FormNth(form, 1);
        // Keep the variable as-is (SyntaxObject or symbol) — compiler resolves
        object expr = ExpandForm(pos, FormNth(form, 2));
        return ((Pair)Pair.List(CoreFormId("set!"), var, expr)).WithPos(pos);
    }

    /// <summary>
    /// Expand a sequence of forms (begin body).
    /// Handles define-syntax visibility: each define-syntax is processed before
    /// expanding subsequent forms, making the macro available to later forms.
    /// </summary>
    private object ExpandBegin(SourcePos? pos, object forms)
    {
        if (forms == Value.NIL) return Value.NIL;

        var expandedForms = new List<object>();
        object current = forms;
        while (current != Value.NIL)
        {
            if (!Value.IsPair(current)) break;

            object form = Value.AsPair(current).car;
            object expanded = ExpandForm(pos, form);

            // After expanding, check if result is a begin — splice it
            if (Value.IsPair(expanded) && Value.IsSymbol(Value.AsPair(expanded).car)
                && Value.AsSymbol(Value.AsPair(expanded).car) == "begin")
            {
                // Splice: add each sub-form
                object inner = Value.AsPair(expanded).cdr;
                while (inner != Value.NIL && Value.IsPair(inner))
                {
                    expandedForms.Add(Value.AsPair(inner).car);
                    inner = Value.AsPair(inner).cdr;
                }
            }
            else
            {
                expandedForms.Add(expanded);
            }

            current = Value.AsPair(current).cdr;
        }

        if (expandedForms.Count == 0) return Value.NIL;
        if (expandedForms.Count == 1) return expandedForms[0];

        // Build (begin expanded1 expanded2 ...)
        object result = Value.NIL;
        for (int i = expandedForms.Count - 1; i >= 0; i--)
            result = new Pair(expandedForms[i], result);
        return new Pair(CoreFormId("begin"), result).WithPos(pos);
    }

    private object ExpandLambda(SourcePos? pos, object form)
    {
        object parms = FormNth(form, 1);
        object body = FormNthCdr(form, 2);

        // Sets-of-scopes protocol: generate a fresh scope for the lambda's
        // parameter bindings. Add it to both parameters and body.
        int scope = SyntaxObject.FreshScope();

        // Add scope to parameters and body
        object scopedParms = SyntaxObject.AddScope(parms, scope);
        object scopedBody = SyntaxObject.AddScope(body, scope);

        // Register each parameter in the binding table
        RegisterParamBindings(scopedParms);

        object expandedBody = ExpandBody(pos, scopedBody);

        return BuildLambda(scopedParms, expandedBody, pos);
    }

    /// <summary>
    /// Register parameter bindings in the binding table.
    /// Each parameter identifier gets a local binding entry with its scope set.
    /// </summary>
    private void RegisterParamBindings(object parms)
    {
        object cur = parms;
        while (true)
        {
            if (cur is SyntaxObject stx)
            {
                if (stx.IsIdentifier)
                {
                    // Rest parameter (dotted list tail or single symbol)
                    bindingTable.Add(stx.SymbolName, stx.Scopes,
                        ResolvedBinding.MakeLocalRef(stx.SymbolName, stx));
                    return;
                }
                // Should not happen — pairs aren't wrapped in sets-of-scopes
                return;
            }
            if (cur == Value.NIL) return;
            if (Value.IsSymbol(cur))
            {
                // Plain symbol rest parameter — no SyntaxObject, skip
                return;
            }
            if (Value.IsPair(cur))
            {
                object car = Value.AsPair(cur).car;
                if (car is SyntaxObject paramStx && paramStx.IsIdentifier)
                {
                    bindingTable.Add(paramStx.SymbolName, paramStx.Scopes,
                        ResolvedBinding.MakeLocalRef(paramStx.SymbolName, paramStx));
                }
                cur = Value.AsPair(cur).cdr;
                continue;
            }
            return;
        }
    }

    /// <summary>
    /// Expand a lambda/let body, handling internal definitions per R7RS 5.3.2.
    /// Scans expanded forms for leading defines, collects them, and builds
    /// a letrec* form. define-syntax is already handled by ExpandDefineSyntax
    /// (which produces a (define name ...) form). begin forms are spliced.
    /// </summary>
    private object ExpandBody(SourcePos? pos, object body)
    {
        // Phase 1: partially expand forms to discover definitions.
        // Macros are expanded one step at a time (splicing begins,
        // evaluating define-syntax) until each form is classified as
        // a define or an expression. Forms are NOT fully expanded yet.
        var allForms = new List<object>();
        object current = body;
        while (current != Value.NIL)
        {
            if (!Value.IsPair(current)) break;
            PartialExpandBodyForm(pos, Value.AsPair(current).car, allForms);
            current = Value.AsPair(current).cdr;
        }

        // Phase 2: separate leading definitions from expressions (raw forms).
        // For defines, handle function shorthand (define (f args) body)
        // by converting to (define f (lambda ...)) before extracting name/expr.
        var defineNames = new List<object>();
        var defineExprs = new List<object>();
        var rawExpressions = new List<object>();
        bool inDefines = true;
        string? docstring = null;

        foreach (var form in allForms)
        {
            if (inDefines && IsDefineForm(form))
            {
                object nameOrPair = GetSecond(form);
                if (Value.IsPair(nameOrPair))
                {
                    // (define (f args...) body...) → name = f, expr = (lambda (args...) body...)
                    Pair np = Value.AsPair(nameOrPair);
                    defineNames.Add(np.car);
                    object args = np.cdr;
                    object defBody = FormNthCdr(form, 2);
                    var lambdaParts = new List<object> { CoreFormId("lambda"), args };
                    object cur = defBody;
                    while (cur != Value.NIL && Value.IsPair(cur))
                    {
                        lambdaParts.Add(Value.AsPair(cur).car);
                        cur = Value.AsPair(cur).cdr;
                    }
                    defineExprs.Add(Pair.List(lambdaParts.ToArray()));
                }
                else
                {
                    // (define name expr)
                    defineNames.Add(nameOrPair);
                    defineExprs.Add(FormLength(form) >= 3 ? GetThird(form) : Value.NIL);
                }
            }
            else if (inDefines && form is char[] docChars && rawExpressions.Count == 0 && defineNames.Count == 0)
            {
                docstring = new string(docChars);
            }
            else
            {
                if (inDefines) inDefines = false;
                rawExpressions.Add(form);
            }
        }

        // Validate: no defines after expressions
        foreach (var expr in rawExpressions)
        {
            if (IsDefineForm(expr))
                throw new SchemeError(pos,
                    "define not allowed here: internal definitions must precede all expressions in a body");
        }

        // Phase 3: if no defines, just expand all forms and return
        if (defineNames.Count == 0)
        {
            var expandedForms = new List<object>();
            if (docstring != null)
                expandedForms.Add(docstring.ToCharArray());
            var source = rawExpressions.Count > 0 ? rawExpressions : allForms;
            foreach (var form in source)
                expandedForms.Add(ExpandForm(pos, form));
            object result = Value.NIL;
            for (int i = expandedForms.Count - 1; i >= 0; i--)
                result = new Pair(expandedForms[i], result);
            return result;
        }

        // Phase 4: create letrec* scope, add it to ALL forms, register
        // define names, THEN expand everything with the scope in place.
        // This follows the sets-of-scopes algorithm: the letrec* scope
        // is established first so that all names are visible during
        // expansion of both init expressions and body expressions.
        int letrecScope = SyntaxObject.FreshScope();

        // Add scope to all define names and register them
        var scopedNames = new List<object>();
        for (int i = 0; i < defineNames.Count; i++)
        {
            object scopedName = SyntaxObject.AddScope(defineNames[i], letrecScope);
            scopedNames.Add(scopedName);
            if (scopedName is SyntaxObject varStx && varStx.IsIdentifier)
                bindingTable.Add(varStx.SymbolName, varStx.Scopes,
                    ResolvedBinding.MakeLocalRef(varStx.SymbolName, varStx));
        }

        // Add scope to init expressions, expand them, then re-add scope.
        // The re-add ensures that template-introduced identifiers from macros
        // expanded during this phase also carry the letrec* scope, enabling
        // forward references through macros (e.g., a macro template that
        // references a later definition). AddScope is idempotent — identifiers
        // that already have the scope are unaffected.
        var scopedBindingPairs = new List<object>();
        for (int i = 0; i < defineNames.Count; i++)
        {
            object scopedExpr = SyntaxObject.AddScope(defineExprs[i], letrecScope);
            object expandedExpr = ExpandForm(pos, scopedExpr);
            expandedExpr = SyntaxObject.AddScope(expandedExpr, letrecScope);
            scopedBindingPairs.Add(Pair.List(scopedNames[i], expandedExpr));
        }

        // Add scope to body expressions, expand them, then re-add scope
        var scopedExpressions = new List<object>();
        foreach (var expr in rawExpressions)
        {
            object scopedExpr = SyntaxObject.AddScope(expr, letrecScope);
            object expandedExpr = ExpandForm(pos, scopedExpr);
            scopedExpressions.Add(SyntaxObject.AddScope(expandedExpr, letrecScope));
        }
        if (scopedExpressions.Count == 0)
            scopedExpressions.Add(Value.NIL);

        // Produce the (letrec* ...) form directly for the compiler
        var letrecParts = new List<object>();
        letrecParts.Add(CoreFormId("letrec*"));
        letrecParts.Add(Pair.List(scopedBindingPairs.ToArray()));
        letrecParts.AddRange(scopedExpressions);
        object expandedLetrec = Pair.List(letrecParts.ToArray());

        // Return body with docstring OUTSIDE the letrec so CompLambda can detect it
        if (docstring != null)
            return new Pair(docstring.ToCharArray(), new Pair(expandedLetrec, Value.NIL));
        return new Pair(expandedLetrec, Value.NIL);
    }

    /// <summary>
    /// Partially expand a body form to discover definitions.
    /// Macros are expanded one step at a time using only the intro scope
    /// (no use-site scope). This ensures pass-through identifiers in
    /// macro-generated definitions retain their original scopes, so the
    /// extracted define names can be correctly registered with the letrec*
    /// scope in Phase 4.
    ///
    /// The intro scope alone provides sufficient hygiene for this discovery
    /// step: template-introduced names get it added (distinguishing them
    /// from user names), while pass-through names have it added then removed
    /// by the flip (returning to original scopes).
    ///
    /// Full expansion (with use-site scopes) happens later in Phase 4
    /// after the letrec* scope and bindings are established.
    /// </summary>
    private void PartialExpandBodyForm(SourcePos? pos, object form, List<object> results)
    {
        while (true)
        {
            if (!Value.IsPair(form) || form == Value.NIL)
            {
                results.Add(form);
                return;
            }

            Pair formPair = Value.AsPair(form);
            pos = formPair.pos ?? pos;
            object head = formPair.car;

            if (head is SyntaxObject headStx && headStx.IsIdentifier)
            {
                var headBinding = SyntaxObject.Resolve(headStx, bindingTable);

                if (headBinding != null)
                {
                    if (headBinding.BindingKind == ResolvedBinding.Kind.CoreForm)
                    {
                        switch (headBinding.SymbolName)
                        {
                            case "define":
                                results.Add(form);
                                return;

                            case "define-syntax":
                                // Evaluate and register the macro (side effect needed
                                // for subsequent forms), then add the result
                                results.Add(ExpandDefineSyntax(pos, form, inBodyContext: true));
                                return;

                            case "begin":
                                // Splice: process each sub-form recursively
                                {
                                    object subForms = GetCdr(form);
                                    while (subForms != Value.NIL && Value.IsPair(subForms))
                                    {
                                        PartialExpandBodyForm(pos, Value.AsPair(subForms).car, results);
                                        subForms = Value.AsPair(subForms).cdr;
                                    }
                                }
                                return;

                            case "let-syntax":
                            case "letrec-syntax":
                                // Per R7RS 5.3.2, let-syntax and letrec-syntax are
                                // transparent in definition contexts: evaluate the
                                // syntax bindings, then splice the body forms.
                                {
                                    object expanded = headBinding.SymbolName == "let-syntax"
                                        ? ExpandLetSyntax(pos, form)
                                        : ExpandLetrecSyntax(pos, form);
                                    // ExpandLetSyntax/ExpandLetrecSyntax returns
                                    // ExpandBegin result — may be a begin or single form
                                    if (IsBeginForm(expanded))
                                    {
                                        object beginBody = GetCdr(expanded);
                                        while (beginBody != Value.NIL && Value.IsPair(beginBody))
                                        {
                                            PartialExpandBodyForm(pos,
                                                Value.AsPair(beginBody).car, results);
                                            beginBody = Value.AsPair(beginBody).cdr;
                                        }
                                    }
                                    else
                                    {
                                        PartialExpandBodyForm(pos, expanded, results);
                                    }
                                }
                                return;

                            default:
                                results.Add(form);
                                return;
                        }
                    }

                    if (headBinding.BindingKind == ResolvedBinding.Kind.Macro)
                    {
                        if (!(headBinding.Value is SyntaxRulesTransformer srt))
                        {
                            results.Add(form);
                            return;
                        }

                        // Expand one macro step with intro scope only (no use-site scope).
                        // This keeps pass-through identifiers at their original scopes
                        // so define names can be correctly pre-registered.
                        int introScope = SyntaxObject.FreshScope();

                        object scopedInput = SyntaxObject.AddScope(form, introScope);

                        object args = Value.IsPair(scopedInput)
                            ? Value.AsPair(scopedInput).cdr : Value.NIL;

                        object result;
                        try { result = srt.TransformRaw(args, modules); }
                        catch (SchemeError e)
                        {
                            throw new SchemeError(e, pos,
                                "error in expansion of macro ~a", headBinding.SymbolName);
                        }

                        result = SyntaxObject.FlipScope(result, introScope);

                        // Continue partial expansion with the result
                        form = result;
                        continue;
                    }
                }
            }
            else if (Value.IsSymbol(head))
            {
                string symName = Value.AsSymbol(head);
                if (symName == "define" || symName == "define-syntax")
                {
                    results.Add(form);
                    return;
                }
                if (symName == "begin")
                {
                    object subForms = GetCdr(form);
                    while (subForms != Value.NIL && Value.IsPair(subForms))
                    {
                        PartialExpandBodyForm(pos, Value.AsPair(subForms).car, results);
                        subForms = Value.AsPair(subForms).cdr;
                    }
                    return;
                }
            }

            // Not a define, begin, or macro — it's an expression
            results.Add(form);
            return;
        }
    }

    /// <summary>Check if a form is (define ...)</summary>
    private static bool IsDefineForm(object form)
    {
        if (!Value.IsPair(form) || form == Value.NIL) return false;
        object head = Value.AsPair(form).car;
        if (Value.IsSymbol(head)) return Value.AsSymbol(head) == "define";
        if (head is SyntaxObject stx && stx.IsIdentifier) return stx.SymbolName == "define";
        return false;
    }

    /// <summary>Check if a form is (begin ...)</summary>
    private static bool IsBeginForm(object form)
    {
        if (!Value.IsPair(form) || form == Value.NIL) return false;
        object head = Value.AsPair(form).car;
        if (Value.IsSymbol(head)) return Value.AsSymbol(head) == "begin";
        if (head is SyntaxObject stx && stx.IsIdentifier) return stx.SymbolName == "begin";
        return false;
    }

    /// <summary>Get cdr of a form.</summary>
    private static object GetCdr(object form)
    {
        if (Value.IsPair(form)) return Value.AsPair(form).cdr;
        return Value.NIL;
    }

    /// <summary>Get second element (car of cdr).</summary>
    private static object GetSecond(object form)
    {
        object cdr = GetCdr(form);
        if (Value.IsPair(cdr)) return Value.AsPair(cdr).car;
        return Value.NIL;
    }

    /// <summary>Get third element.</summary>
    private static object GetThird(object form)
    {
        object cdr = GetCdr(form);
        if (!Value.IsPair(cdr)) return Value.NIL;
        object cddr = Value.AsPair(cdr).cdr;
        if (!Value.IsPair(cddr)) return Value.NIL;
        return Value.AsPair(cddr).car;
    }

    private object BuildLambda(object parms, object body, SourcePos? pos)
    {
        var elements = new List<object>();
        elements.Add(CoreFormId("lambda"));
        elements.Add(parms);
        object cur = body;
        while (cur != Value.NIL && Value.IsPair(cur))
        {
            elements.Add(Value.AsPair(cur).car);
            cur = Value.AsPair(cur).cdr;
        }
        return ((Pair)Pair.List(elements.ToArray())).WithPos(pos);
    }

    /// <summary>
    /// Expand a define form.
    /// (define x expr) → (define x expanded-expr)
    /// (define (f args...) body...) → (define f (lambda (args...) expanded-body...))
    /// </summary>
    private object ExpandDefine(SourcePos? pos, object form)
    {
        object nameOrPair = FormNth(form, 1);

        if (Value.IsPair(nameOrPair))
        {
            // (define (f args...) body...) → (define f (lambda (args...) body...))
            Pair np = Value.AsPair(nameOrPair);
            object name = np.car;
            // Keep name as SyntaxObject for hygiene — scope-based comparison
            // must distinguish macro-introduced defines from user defines.
            object args = np.cdr;
            object body = FormNthCdr(form, 2);
            // Build a lambda form and expand it through ExpandLambda
            // so that scope bindings are properly applied.
            var lambdaParts = new List<object> { CoreFormId("lambda"), args };
            object cur = body;
            while (true)
            {
                if (cur == Value.NIL || !Value.IsPair(cur)) break;
                lambdaParts.Add(Value.AsPair(cur).car);
                cur = Value.AsPair(cur).cdr;
            }
            object lambdaForm = Pair.List(lambdaParts.ToArray());
            object expandedLambda = ExpandLambda(pos, lambdaForm);

            // Register top-level define in binding table so subsequent macros
            // whose templates reference this name can resolve it
            RegisterTopLevelDefine(name);

            return ((Pair)Pair.List(CoreFormId("define"), name, expandedLambda)).WithPos(pos);
        }
        else
        {
            // (define name expr) — keep name as SyntaxObject for hygiene
            object name = nameOrPair;
            object expr = FormNth(form, 2);
            object expandedExpr = ExpandForm(pos, expr);

            // Register top-level define in binding table
            RegisterTopLevelDefine(name);

            return ((Pair)Pair.List(CoreFormId("define"), name, expandedExpr)).WithPos(pos);
        }
    }

    /// <summary>
    /// Register a top-level define in the binding table so that macro templates
    /// referencing this name can resolve it during expansion.
    /// </summary>
    private void RegisterTopLevelDefine(object name)
    {
        string symName;
        if (name is SyntaxObject nameStx && nameStx.IsIdentifier)
            symName = nameStx.SymbolName;
        else if (Value.IsSymbol(name))
            symName = Value.AsSymbol(name);
        else
            return;

        int moduleScope = modules.GetCurrentModuleScope();
        string moduleName = modules.GetCurrentModule().Name;
        string originModule = moduleName;
        bindingTable.Add(symName, ScopeSet.Of(moduleScope),
            new ResolvedBinding(
                ResolvedBinding.Kind.Global,
                originModule + ":" + symName,
                moduleName, symName, symName, null));
    }

    /// <summary>
    /// Expand (let ((var val) ...) body ...) and (let name ((var val) ...) body ...)
    /// These are core forms handled directly by the Compiler.
    /// </summary>
    private object ExpandLet(SourcePos? pos, object form)
    {
        object second = FormNth(form, 1);

        bool isNamed = second is SyntaxObject si && si.IsIdentifier
                    || (Value.IsSymbol(second) && !Value.IsPair(second));

        if (isNamed)
        {
            // Named let: (let name ((var val) ...) body ...)
            object name = second;
            object bindings = FormNth(form, 2);
            object body = FormNthCdr(form, 3);

            // Expand values in outer scope
            object expandedBindings = ExpandBindings(pos, bindings);

            // Fresh scope for bound variables
            int scope = SyntaxObject.FreshScope();
            object scopedBindings = ScopeBindingVars(expandedBindings, scope);
            RegisterBindingVarBindings(scopedBindings);

            // Scope the loop name too
            object scopedName = SyntaxObject.AddScope(name, scope);
            if (scopedName is SyntaxObject nameStx && nameStx.IsIdentifier)
            {
                bindingTable.Add(nameStx.SymbolName, nameStx.Scopes,
                    ResolvedBinding.MakeLocalRef(nameStx.SymbolName, nameStx));
            }

            object scopedBody = SyntaxObject.AddScope(body, scope);
            object expandedBody = ExpandBody(pos, scopedBody);

            var parts = new List<object> { CoreFormId("let"), scopedName, scopedBindings };
            AppendList(parts, expandedBody);
            return ((Pair)Pair.List(parts.ToArray())).WithPos(pos);
        }
        else
        {
            // Simple let: (let ((var val) ...) body ...)
            object bindings = second;
            object body = FormNthCdr(form, 2);

            // Expand values in outer scope
            object expandedBindings = ExpandBindings(pos, bindings);

            // Fresh scope for bound variables
            int scope = SyntaxObject.FreshScope();
            object scopedBindings = ScopeBindingVars(expandedBindings, scope);
            RegisterBindingVarBindings(scopedBindings);

            object scopedBody = SyntaxObject.AddScope(body, scope);
            object expandedBody = ExpandBody(pos, scopedBody);

            var parts = new List<object> { CoreFormId("let"), scopedBindings };
            AppendList(parts, expandedBody);
            return ((Pair)Pair.List(parts.ToArray())).WithPos(pos);
        }
    }

    /// <summary>
    /// Walk a binding list ((var val) ...), add scope to each variable,
    /// and return the updated binding list with scoped variables.
    /// </summary>
    private object ScopeBindingVars(object bindings, int scope)
    {
        var result = new List<object>();
        object cur = bindings;
        while (cur != Value.NIL && Value.IsPair(cur))
        {
            object binding = Value.AsPair(cur).car;
            if (Value.IsPair(binding))
            {
                object var = Value.AsPair(binding).car;
                object val = Value.AsPair(Value.AsPair(binding).cdr).car;
                object scopedVar = SyntaxObject.AddScope(var, scope);
                result.Add(Pair.List(scopedVar, val));
            }
            else
            {
                result.Add(binding);
            }
            cur = Value.AsPair(cur).cdr;
        }
        return Pair.List(result.ToArray());
    }

    /// <summary>
    /// Register binding table entries for each variable in a scoped binding list.
    /// The variables should already have the scope added.
    /// </summary>
    private void RegisterBindingVarBindings(object bindings)
    {
        object cur = bindings;
        while (cur != Value.NIL && Value.IsPair(cur))
        {
            object binding = Value.AsPair(cur).car;
            if (Value.IsPair(binding))
            {
                object var = Value.AsPair(binding).car;
                if (var is SyntaxObject varStx && varStx.IsIdentifier)
                {
                    bindingTable.Add(varStx.SymbolName, varStx.Scopes,
                        ResolvedBinding.MakeLocalRef(varStx.SymbolName, varStx));
                }
            }
            cur = Value.AsPair(cur).cdr;
        }
    }

    /// <summary>Expand (let* ((var val) ...) body ...)</summary>
    private object ExpandLetStar(SourcePos? pos, object form)
    {
        object bindings = FormNth(form, 1);
        object body = FormNthCdr(form, 2);

        // Expand let* as nested let forms so each binding gets its own
        // scope. This ensures sequential scoping: each binding only sees
        // previous bindings, not future ones.
        return ExpandLetStarAsNestedLets(pos, bindings, body);
    }

    /// <summary>
    /// Expand (let* ((v1 e1) (v2 e2) ...) body...) by directly handling
    /// scoping for each binding sequentially. Each binding gets a fresh scope
    /// that is visible to subsequent bindings and the body.
    /// Returns nested (let ...) forms for the compiler.
    /// </summary>
    private object ExpandLetStarAsNestedLets(SourcePos? pos, object bindings, object body)
    {
        if (bindings == Value.NIL || !Value.IsPair(bindings))
        {
            // No bindings left — expand body
            object expandedBody = ExpandBody(pos, body);
            // Wrap in begin if multiple forms
            return WrapBegin(expandedBody);
        }

        // Take first binding
        object firstBinding = Value.AsPair(bindings).car;
        object restBindings = Value.AsPair(bindings).cdr;

        // Expand the init expression in the current scope
        object var = Value.AsPair(firstBinding).car;
        object initExpr = Value.IsPair(Value.AsPair(firstBinding).cdr)
            ? Value.AsPair(Value.AsPair(firstBinding).cdr).car
            : Value.F;
        object expandedInit = ExpandForm(pos, initExpr);

        // Fresh scope for this binding
        int scope = SyntaxObject.FreshScope();
        object scopedVar = SyntaxObject.AddScope(var, scope);

        // Register the binding in the binding table
        if (scopedVar is SyntaxObject varStx && varStx.IsIdentifier)
        {
            bindingTable.Add(varStx.SymbolName, varStx.Scopes,
                ResolvedBinding.MakeLocalRef(varStx.SymbolName, varStx));
        }

        // Add scope to remaining bindings and body
        object scopedRestBindings = SyntaxObject.AddScope(restBindings, scope);
        object scopedBody = SyntaxObject.AddScope(body, scope);

        // Recursively expand remaining bindings
        object inner = ExpandLetStarAsNestedLets(pos, scopedRestBindings, scopedBody);

        // Build (let ((var init)) inner) for the compiler
        object expandedBinding = Pair.List(scopedVar, expandedInit);
        return ((Pair)Pair.List(CoreFormId("let"), Pair.List(expandedBinding), inner)).WithPos(pos);
    }

    /// <summary>
    /// Wrap a list of expanded body forms as a single expression.
    /// Single form: return as-is. Multiple: wrap in (begin ...).
    /// </summary>
    private object WrapBegin(object forms)
    {
        if (forms == Value.NIL) return Value.F;
        if (!Value.IsPair(forms)) return forms;
        if (Value.AsPair(forms).cdr == Value.NIL)
            return Value.AsPair(forms).car; // single form
        return new Pair(CoreFormId("begin"), forms);
    }

    /// <summary>Expand (letrec ((var val) ...) body ...) or (letrec* ...)</summary>
    private object ExpandLetrec(SourcePos? pos, object form, string name)
    {
        object bindings = FormNth(form, 1);
        object body = FormNthCdr(form, 2);
        return ExpandLetRecCommon(pos, bindings, body, name);
    }

    /// <summary>
    /// Common expansion for letrec, letrec*: values can reference bindings,
    /// so the scope is applied to BOTH bindings and body.
    /// </summary>
    private object ExpandLetRecCommon(SourcePos? pos, object bindings, object body, string name)
    {
        int scope = SyntaxObject.FreshScope();

        // Add scope to BOTH bindings and body (letrec semantics)
        object scopedBindings = SyntaxObject.AddScope(bindings, scope);
        object scopedBody = SyntaxObject.AddScope(body, scope);

        // Register binding table entries for each variable
        RegisterRawBindingVarBindings(scopedBindings);

        // Now expand the values (in the scoped context, so they can see each other)
        object expandedBindings = ExpandBindings(pos, scopedBindings);
        object expandedBody = ExpandBody(pos, scopedBody);

        var parts = new List<object> { CoreFormId(name), expandedBindings };
        AppendList(parts, expandedBody);
        return ((Pair)Pair.List(parts.ToArray())).WithPos(pos);
    }

    /// <summary>
    /// Register binding table entries from a scoped binding list.
    /// The variables should already have the scope added.
    /// </summary>
    private void RegisterRawBindingVarBindings(object bindings)
    {
        object cur = bindings;
        while (true)
        {
            if (cur == Value.NIL || !Value.IsPair(cur)) break;
            object binding = Value.AsPair(cur).car;
            if (Value.IsPair(binding))
            {
                object var = Value.AsPair(binding).car;
                if (var is SyntaxObject varStx && varStx.IsIdentifier)
                {
                    bindingTable.Add(varStx.SymbolName, varStx.Scopes,
                        ResolvedBinding.MakeLocalRef(varStx.SymbolName, varStx));
                }
            }
            cur = Value.AsPair(cur).cdr;
        }
    }

    /// <summary>Expand binding list ((var val) ...) — expand each val expression.</summary>
    private object ExpandBindings(SourcePos? pos, object bindings)
    {
        var result = new List<object>();
        object cur = bindings;
        while (cur != Value.NIL)
        {
            if (!Value.IsPair(cur)) break;
            object binding = Value.AsPair(cur).car;
            if (Value.IsPair(binding))
            {
                object var = Value.AsPair(binding).car;
                object valExpr = Value.NIL;
                object bindCdr = Value.AsPair(binding).cdr;
                if (Value.IsPair(bindCdr))
                    valExpr = Value.AsPair(bindCdr).car;
                object expandedVal = ExpandForm(pos, valExpr);
                result.Add(Pair.List(var, expandedVal));
            }
            else
            {
                result.Add(binding);
            }
            cur = Value.AsPair(cur).cdr;
        }
        return Pair.List(result.ToArray());
    }

    /// <summary>Append elements from a Pair list to a C# list.</summary>
    private static void AppendList(List<object> target, object pairList)
    {
        object cur = pairList;
        while (cur != Value.NIL && Value.IsPair(cur))
        {
            target.Add(Value.AsPair(cur).car);
            cur = Value.AsPair(cur).cdr;
        }
    }

    /// <summary>
    /// Expand define-syntax: evaluate the transformer, bind it as a macro,
    /// and produce a runtime binding for the module system.
    /// </summary>
    private object ExpandDefineSyntax(SourcePos? pos, object form, bool inBodyContext = false)
    {
        // In body contexts (let/lambda bodies), the name carries body scopes that
        // prevent the macro from leaking into the global scope. At the top level,
        // macro-generated define-syntax may have intro/use-site scopes on the name
        // that should NOT restrict visibility — use moduleScope only.
        object nameObj = FormNth(form, 1);
        int moduleScope = modules.GetCurrentModuleScope();
        ScopeSet macroScopes;
        if (inBodyContext && nameObj is SyntaxObject nameStx && nameStx.IsIdentifier)
        {
            macroScopes = nameStx.Scopes;
            nameObj = nameStx.SymbolName;
        }
        else
        {
            if (nameObj is SyntaxObject ns && ns.IsIdentifier) nameObj = ns.SymbolName;
            macroScopes = ScopeSet.Of(moduleScope);
        }
        string name = Value.AsSymbol(nameObj);

        int len = FormLength(form);
        object transformerExpr = (len == 4) ? FormNth(form, 3) : FormNth(form, 2);

        // Evaluate the transformer expression
        object transformer = EvalTransformerInExpander(pos, transformerExpr);

        // Build macro binding
        string? docstring = (len == 4) ? new string(Value.AsString(SyntaxObject.Strip(FormNth(form, 2)))) : null;
        object macroPair = new MacroTransformer(transformer, docstring);

        // Only store in module bindings at module level (no extra body scopes).
        // Inside let/lambda bodies, the macro should be scoped — not globally visible.
        if (macroScopes.SetEquals(ScopeSet.Of(moduleScope)))
            modules.GetCurrentModule().Bind(name, macroPair);

        // Register in the binding table with the name's actual scopes
        bindingTable.Add(name, macroScopes,
            ResolvedBinding.MakeMacro(modules.GetCurrentModule().Name, name, transformer));

        // Produce a define form for the runtime so the binding persists
        // and doesn't break internal-definition scanning in lambda bodies.
        // Use a plain symbol for the variable — this define is an implementation
        // detail for the module system, not a user-visible binding that participates
        // in scope-based resolution.
        return ((Pair)Pair.List(CoreFormId("define"), Value.Intern(name),
            Pair.List(CoreFormId("quote"), macroPair))).WithPos(pos);
    }

    /// <summary>
    /// Evaluate a transformer expression. Must be (syntax-rules ...).
    /// </summary>
    private object EvalTransformerInExpander(SourcePos? pos, object expr)
    {
        // In sets-of-scopes, pairs aren't wrapped. Just check if it's a pair.
        if (Value.IsPair(expr))
        {
            object head = Value.AsPair(expr).car;
            string? headName = null;
            if (head is SyntaxObject hStx && hStx.IsIdentifier)
                headName = hStx.SymbolName;
            else if (Value.IsSymbol(head))
                headName = Value.AsSymbol(head);
            if (headName == "syntax-rules")
            {
                return SyntaxRulesTransformer.Parse(
                    Value.AsPair(expr).cdr,
                    modules.GetCurrentModule().Name,
                    modules);
            }
        }

        throw new SchemeError(pos, "define-syntax: expected (syntax-rules ...) transformer");
    }

    private object ExpandLetSyntax(SourcePos? pos, object form)
    {
        object bindings = FormNth(form, 1);  // the bindings list
        object body = FormNthCdr(form, 2);   // the body forms

        // Fresh scope for the let-syntax body
        int scope = SyntaxObject.FreshScope();

        // Evaluate each transformer and register macro bindings
        object b = bindings;
        while (b != Value.NIL && Value.IsPair(b))
        {
            object binding = Value.AsPair(b).car;
            if (Value.IsPair(binding))
            {
                Pair bp = Value.AsPair(binding);
                object nameObj = bp.First();
                // Add the fresh scope to the name identifier so its scopes
                // match what body identifiers will carry (preserves cross-module scopes)
                nameObj = SyntaxObject.AddScope(nameObj, scope);
                ScopeSet macroScopes;
                string name;
                if (nameObj is SyntaxObject nStx && nStx.IsIdentifier)
                {
                    name = nStx.SymbolName;
                    macroScopes = nStx.Scopes;
                }
                else
                {
                    name = Value.AsSymbol(nameObj);
                    macroScopes = ScopeSet.Of(modules.GetCurrentModuleScope()).Add(scope);
                }
                object bpCdr = bp.cdr;
                object transformerExpr = Value.IsPair(bpCdr) ? Value.AsPair(bpCdr).car : Value.NIL;
                object transformer = EvalTransformerInExpander(pos, transformerExpr);

                // Register in binding table with scopes from the name identifier
                bindingTable.Add(name, macroScopes,
                    ResolvedBinding.MakeMacro(modules.GetCurrentModule().Name, name, transformer));
            }

            b = Value.AsPair(b).cdr;
        }

        // Add scope to body and expand
        object scopedBody = SyntaxObject.AddScope(body, scope);
        return ExpandBegin(pos, scopedBody);
    }

    private object ExpandLetrecSyntax(SourcePos? pos, object form)
    {
        object bindings = FormNth(form, 1);
        object body = FormNthCdr(form, 2);

        int scope = SyntaxObject.FreshScope();
        string moduleName = modules.GetCurrentModule().Name;

        // Add scope to bindings so template identifiers carry the letrec scope
        // (analogous to ExpandLetRecCommon scoping bindings before expansion)
        object scopedBindings = SyntaxObject.AddScope(bindings, scope);

        // Pass 1: parse all transformers and collect (name, scopes, transformer) triples
        var macros = new List<(string name, ScopeSet scopes, object transformer)>();
        object b = scopedBindings;
        while (b != Value.NIL && Value.IsPair(b))
        {
            object binding = Value.AsPair(b).car;
            if (Value.IsPair(binding))
            {
                Pair bp = Value.AsPair(binding);
                object nameObj = bp.First();
                // Use the identifier's actual scopes (which include the fresh scope
                // from scopedBindings and any cross-module expansion scopes)
                ScopeSet macroScopes;
                string name;
                if (nameObj is SyntaxObject nStx && nStx.IsIdentifier)
                {
                    name = nStx.SymbolName;
                    macroScopes = nStx.Scopes;
                }
                else
                {
                    name = Value.AsSymbol(nameObj);
                    macroScopes = ScopeSet.Of(modules.GetCurrentModuleScope()).Add(scope);
                }
                object bpCdr = bp.cdr;
                object transformerExpr = Value.IsPair(bpCdr) ? Value.AsPair(bpCdr).car : Value.NIL;
                object transformer = EvalTransformerInExpander(pos, transformerExpr);
                macros.Add((name, macroScopes, transformer));
            }
            b = Value.AsPair(b).cdr;
        }

        // Pass 2: register all bindings in binding table at once
        foreach (var (name, macroScopes, transformer) in macros)
        {
            bindingTable.Add(name, macroScopes,
                ResolvedBinding.MakeMacro(moduleName, name, transformer));
        }

        // Add scope to body and expand
        object scopedBody = SyntaxObject.AddScope(body, scope);
        return ExpandBegin(pos, scopedBody);
    }

    /// <summary>
    /// Expand (cond-expand clause ...) at expansion time.
    /// Process a single import set: load the module, register bindings in both
    /// Module.Bindings (for VM runtime) and the binding table (for expansion/compilation).
    /// </summary>
    private void DoImportSet(SourcePos? pos, object importSpec)
    {
        var importer = (PrimitiveDoImportSet)modules.primitives.GetPrimitive("%do-import-set");
        var importResult = importer.DoImportSet(pos, importSpec);
        var module = modules.GetCurrentModule();
        int modScope = modules.GetCurrentModuleScope();
        var scopeSet = ScopeSet.Of(modScope);

        foreach (var kv in importResult.Bindings)
        {
            string name = kv.Key;
            object value = kv.Value;
            string origin = importResult.Provenance[name];

            // Register in Module.Bindings for VM runtime
            module.ImportBinding(pos, name, value, origin);

            // Core form markers don't need binding table registration —
            // RegisterCoreFormBindings handles that per module scope
            if (value is CoreFormMarker) continue;

            // Register directly in binding table for expander/compiler
            ResolvedBinding binding;
            if (value is MacroTransformer mt)
            {
                binding = new ResolvedBinding(
                    ResolvedBinding.Kind.Macro,
                    origin + ":" + name,
                    module.Name, name, name,
                    mt.Transformer);
            }
            else
            {
                binding = new ResolvedBinding(
                    ResolvedBinding.Kind.Global,
                    origin + ":" + name,
                    module.Name, name, name, null);
            }
            bindingTable.Add(name, scopeSet, binding);
        }
    }

    /// <summary>
    /// Expand (import spec1 spec2 ...) — process each import set at expansion time.
    /// All work is done during expansion; returns a no-op form for the compiler.
    /// </summary>
    private object ExpandImport(SourcePos? pos, object stx)
    {
        object specs = FormNthCdr(stx, 1);
        while (specs != Value.NIL)
        {
            object spec = SyntaxObject.Strip(Value.AsPair(specs).car);
            try
            {
                DoImportSet(pos, spec);
            }
            catch (SchemeError e) { throw new SchemeError(e, "Failed to import ~a", spec); }
            catch { throw new SchemeError("Failed to import ~a", spec); }
            specs = Value.AsPair(specs).cdr;
        }
        // All import work is done at expansion time; return a no-op for the compiler
        return ((Pair)Pair.List(CoreFormId("begin"))).WithPos(pos);
    }

    /// <summary>
    /// Expand (define-library (name ...) decl ...) — process library declarations
    /// at expansion time. Handles export, import, begin, include, include-ci,
    /// include-library-declarations, and cond-expand clauses.
    /// </summary>
    private object ExpandDefineLibrary(SourcePos? pos, object stx)
    {
        object moduleDecl = SyntaxObject.Strip(FormNth(stx, 1));
        string moduleName = Modules.AsModuleName(moduleDecl);

        var originalName = modules.GetCurrentModule().Name;
        modules.SetCurrentModule(moduleName);
        var module = modules.GetCurrentModule();

        // Register core form bindings for the new module scope
        int modScope = modules.GetCurrentModuleScope();
        bindingTable.RegisterCoreFormBindings(modScope);

        List<object> exports = new();

        try
        {
            object decls = FormNthCdr(stx, 2);
            ProcessLibraryDeclarations(pos, decls, module, exports);

            // Register exports
            foreach (var symbol in exports)
            {
                if (Value.IsPair(symbol))
                {
                    // (rename src dest)
                    var renamePair = Value.AsPair(Value.AsPair(symbol).cdr);
                    var src = Value.AsSymbol(renamePair.car);
                    var dest = Value.AsSymbol(Value.AsPair(renamePair.cdr).car);
                    module.Export(src, dest);
                }
                else
                {
                    module.Export((string) symbol);
                }
            }
        }
        finally
        {
            modules.SetCurrentModule(originalName);
        }

        // All work done at expansion time; return the module name as a quoted value
        return ((Pair)Pair.List(CoreFormId("quote"), moduleDecl)).WithPos(pos);
    }

    /// <summary>
    /// Process a sequence of library declarations (export, import, begin, include, etc.).
    /// </summary>
    private void ProcessLibraryDeclarations(SourcePos? pos, object decls, Module module, List<object> exports)
    {
        while (decls != Value.NIL)
        {
            object decl = SyntaxObject.Strip(Value.AsPair(decls).car);
            ProcessLibraryDeclaration(pos, Value.AsPair(decl), module, exports);
            decls = Value.AsPair(decls).cdr;
        }
    }

    /// <summary>
    /// Process a single library declaration.
    /// </summary>
    private void ProcessLibraryDeclaration(SourcePos? pos, Pair current, Module module, List<object> exports)
    {
        var what = current.car;
        var val = current.cdr;
        var evaluator = modules.Evaluator!;

        if (what.Equals("export"))
        {
            Pair.AppendToList(Value.AsPair(val), exports);
        }
        else if (what.Equals("import"))
        {
            object specs = Value.AsPair(val);
            while (specs != Value.NIL)
            {
                try
                {
                    DoImportSet(pos, Value.AsPair(specs).car);
                }
                catch (SchemeError e) { throw new SchemeError(e, "Failed to import ~a", Value.AsPair(specs).car); }
                catch { throw new SchemeError("Failed to import ~a", Value.AsPair(specs).car); }
                specs = Value.AsPair(specs).cdr;
            }
        }
        else if (what.Equals("include"))
        {
            object filenames = Value.AsPair(val);
            while (filenames != Value.NIL)
            {
                var filename = new string(Value.AsString(Value.AsPair(filenames).car));
                evaluator.EvalFile(filename);
                filenames = Value.AsPair(filenames).cdr;
            }
        }
        else if (what.Equals("include-ci"))
        {
            object filenames = Value.AsPair(val);
            while (filenames != Value.NIL)
            {
                var filename = new string(Value.AsString(Value.AsPair(filenames).car));
                using var stream = new TextStream(new StreamReader(new FileStream(filename, FileMode.Open, FileAccess.Read, FileShare.ReadWrite), Encoding.UTF8), filename);
                stream.FoldCase = true;
                evaluator.EvalFile(stream, filename);
                filenames = Value.AsPair(filenames).cdr;
            }
        }
        else if (what.Equals("include-library-declarations"))
        {
            object filenames = Value.AsPair(val);
            while (filenames != Value.NIL)
            {
                var filename = new string(Value.AsString(Value.AsPair(filenames).car));
                using var stream = new TextStream(new StreamReader(new FileStream(filename, FileMode.Open, FileAccess.Read, FileShare.ReadWrite), Encoding.UTF8), filename);
                object form = evaluator.Read(stream);
                while (!form.Equals(Value.EOF))
                {
                    ProcessLibraryDeclaration(stream.Pos(), Value.AsPair(form), module, exports);
                    form = evaluator.Read(stream);
                }
                filenames = Value.AsPair(filenames).cdr;
            }
        }
        else if (what.Equals("cond-expand"))
        {
            // Library-level cond-expand: clauses produce declarations, not expressions
            var featuresPrim = (Primitive)modules.primitives.GetPrimitive("%features-list");
            object featureList = featuresPrim.Apply(pos, new object[0]);

            object clauses = Value.AsPair(val);
            while (clauses != Value.NIL)
            {
                var clause = Value.AsPair(Value.AsPair(clauses).car);
                var test = clause.car;
                if (FeatureSatisfied(test, featureList))
                {
                    object body = clause.cdr;
                    while (body != Value.NIL)
                    {
                        ProcessLibraryDeclaration(pos, Value.AsPair(Value.AsPair(body).car), module, exports);
                        body = Value.AsPair(body).cdr;
                    }
                    break;
                }
                clauses = Value.AsPair(clauses).cdr;
            }
        }
        else if (what.Equals("begin"))
        {
            evaluator.Eval(pos, current);
        }
    }

    /// <summary>
    /// Each clause is (feature-requirement expr ...). Evaluates feature requirements
    /// and expands the first matching clause as (begin expr ...).
    /// </summary>
    private object ExpandCondExpand(SourcePos? pos, object form)
    {
        // Get the feature list from the primitive
        var featuresPrim = (Primitive)modules.primitives.GetPrimitive("%features-list");
        object featureList = featuresPrim.Apply(pos, new object[0]);

        // Walk clauses
        object clauses = FormNthCdr(form, 1);
        while (clauses != Value.NIL)
        {
            if (!Value.IsPair(clauses)) break;

            object clause = Value.AsPair(clauses).car;
            if (!Value.IsPair(clause)) { clauses = Value.AsPair(clauses).cdr; continue; }

            object req = Value.AsPair(clause).car;
            object body = Value.AsPair(clause).cdr;

            if (FeatureSatisfied(req, featureList))
                return ExpandBegin(pos, body);

            clauses = Value.AsPair(clauses).cdr;
        }

        // No clause matched — return void
        return new Pair(CoreFormId("begin"), Value.NIL);
    }

    /// <summary>
    /// Evaluate a cond-expand feature requirement against the feature list.
    /// Supports: identifier, else, (and ...), (or ...), (not ...), (library ...).
    /// </summary>
    private bool FeatureSatisfied(object req, object featureList)
    {
        // Strip SyntaxObject wrappers for inspection
        object stripped = SyntaxObject.Strip(req);

        // Symbol: check if it's 'else or a feature name
        if (Value.IsSymbol(stripped))
        {
            string name = Value.AsSymbol(stripped);
            if (name == "else") return true;
            // Check membership in feature list
            object cur = featureList;
            while (cur != Value.NIL && Value.IsPair(cur))
            {
                if (Value.IsSymbol(Value.AsPair(cur).car)
                    && Value.AsSymbol(Value.AsPair(cur).car) == name)
                    return true;
                cur = Value.AsPair(cur).cdr;
            }
            return false;
        }

        // Pair: compound requirement
        if (Value.IsPair(stripped))
        {
            object op = Value.AsPair(stripped).car;
            string? opName = Value.IsSymbol(op) ? Value.AsSymbol(op) : null;
            object args = Value.AsPair(stripped).cdr;

            if (opName == "and")
            {
                while (args != Value.NIL && Value.IsPair(args))
                {
                    if (!FeatureSatisfied(Value.AsPair(args).car, featureList))
                        return false;
                    args = Value.AsPair(args).cdr;
                }
                return true;
            }
            if (opName == "or")
            {
                while (args != Value.NIL && Value.IsPair(args))
                {
                    if (FeatureSatisfied(Value.AsPair(args).car, featureList))
                        return true;
                    args = Value.AsPair(args).cdr;
                }
                return false;
            }
            if (opName == "not")
            {
                return !FeatureSatisfied(Value.AsPair(args).car, featureList);
            }
            if (opName == "library")
            {
                // (library <name>) — check if module can be found
                object libName = Value.AsPair(args).car;
                string moduleName = Modules.AsModuleName(SyntaxObject.Strip(libName));
                if (modules.GetModule(moduleName) != null) return true;
                if (ModulePath.FindBuiltinLibraryStream(moduleName, ".sld") != null) return true;
                return ModulePath.FindModule(modules, moduleName) != null;
            }
        }

        return false;
    }

    // ---- Quasiquote Expansion ----

    /// <summary>
    /// Expand a quasiquote form. The datum is the content after stripping
    /// the (quasiquote ...) wrapper. Unquoted sub-expressions are expanded
    /// through ExpandForm, preserving scope-based hygiene.
    /// </summary>
    private object ExpandQuasiquote(SourcePos? pos, object datum)
    {
        return ExpandQQ(pos, datum, 0);
    }

    /// <summary>
    /// Recursive quasiquote expansion with nesting depth tracking.
    /// At nesting 0, unquote/unquote-splicing are active.
    /// At nesting > 0, they are treated as literal data (nested quasiquotes).
    /// </summary>
    private object ExpandQQ(SourcePos? pos, object exp, int nesting)
    {
        // In sets-of-scopes, only identifiers are wrapped in SyntaxObject.
        // Pairs are not wrapped. We just work with pairs directly.
        // If exp is a SyntaxObject identifier, it's a datum (symbol).
        object exposed = exp;
        if (exposed is SyntaxObject soId && soId.IsIdentifier)
        {
            // A bare identifier in quasiquote context — quote it
            return Pair.List(CoreFormId("quote"), SyntaxObject.Strip(exposed));
        }

        // Vector: (apply vector <expanded-list>)
        if (Value.IsVector(exposed))
        {
            var vec = Value.AsVector(exposed);
            object asList = Value.NIL;
            for (int i = vec.Length - 1; i >= 0; i--)
                asList = new Pair(vec[i], asList);
            return Pair.List(CoreFormId("apply"), CoreFormId("vector"),
                ExpandQQ(pos, asList, nesting));
        }

        // Non-pair: constants are self-quoting, symbols get quoted
        if (!Value.IsPair(exposed) || exposed == Value.NIL)
        {
            if (IsQQConstant(exposed))
                return SyntaxObject.Strip(exposed);
            return Pair.List(CoreFormId("quote"), SyntaxObject.Strip(exposed));
        }

        Pair p = Value.AsPair(exposed);
        string? carName = GetQQName(p.car);

        // (unquote expr) — length 2
        if (carName == "unquote" && QQListLength(exposed) == 2)
        {
            object inner = FormNth(p.cdr, 0);
            if (nesting == 0)
                return ExpandForm(pos, inner);  // Full expansion
            return CombineSkeletons(
                Pair.List(CoreFormId("quote"), Value.Intern("unquote")),
                ExpandQQ(pos, p.cdr, nesting - 1),
                SyntaxObject.Strip(exposed));
        }

        // (quasiquote expr) — nested quasiquote, length 2
        if (carName == "quasiquote" && QQListLength(exposed) == 2)
        {
            return CombineSkeletons(
                Pair.List(CoreFormId("quote"), Value.Intern("quasiquote")),
                ExpandQQ(pos, p.cdr, nesting + 1),
                SyntaxObject.Strip(exposed));
        }

        // ((unquote-splicing expr) . rest) — splicing at car position
        object carExposed = p.car;
        if (Value.IsPair(carExposed))
        {
            string? caarName = GetQQName(Value.AsPair(carExposed).car);
            if (caarName == "unquote-splicing" && QQListLength(carExposed) == 2)
            {
                object splicedExpr = FormNth(Value.AsPair(carExposed).cdr, 0);
                if (nesting == 0)
                {
                    return Pair.List(CoreFormId("append"),
                        ExpandForm(pos, splicedExpr),
                        ExpandQQ(pos, p.cdr, nesting));
                }
                return CombineSkeletons(
                    ExpandQQ(pos, p.car, nesting - 1),
                    ExpandQQ(pos, p.cdr, nesting),
                    SyntaxObject.Strip(exposed));
            }
        }

        // Regular pair: combine car and cdr
        return CombineSkeletons(
            ExpandQQ(pos, p.car, nesting),
            ExpandQQ(pos, p.cdr, nesting),
            SyntaxObject.Strip(exposed));
    }

    /// <summary>
    /// Combine expanded car (left) and cdr (right) into an optimal form.
    /// </summary>
    private object CombineSkeletons(object left, object right, object originalExp)
    {
        bool leftConst = IsQQConstant(left);
        bool rightConst = IsQQConstant(right);

        if (leftConst && rightConst)
        {
            object leftVal = IsQuoteForm(left) ? Value.AsPair(left).Second() : left;
            object rightVal = IsQuoteForm(right) ? Value.AsPair(right).Second() : right;
            return Pair.List(CoreFormId("quote"), new Pair(leftVal, rightVal));
        }
        if (rightConst && IsQuoteForm(right)
            && Value.AsPair(right).Second() == Value.NIL)
        {
            return Pair.List(CoreFormId("list"), left);
        }
        string? rightCarName = Value.IsPair(right) ? GetQQName(Value.AsPair(right).car) : null;
        if (rightCarName == "list")
        {
            // (list ...) — prepend left
            var parts = new List<object> { CoreFormId("list"), left };
            object cur = Value.AsPair(right).cdr;
            while (cur != Value.NIL && Value.IsPair(cur))
            {
                parts.Add(Value.AsPair(cur).car);
                cur = Value.AsPair(cur).cdr;
            }
            return Pair.List(parts.ToArray());
        }
        return Pair.List(CoreFormId("cons"), left, right);
    }

    /// <summary>Check if a value is a self-quoting constant or (quote x) form.</summary>
    private static bool IsQQConstant(object x)
    {
        if (x == Value.NIL) return true;
        if (Value.IsConstant(x)) return true;
        if (IsQuoteForm(x)) return true;
        return false;
    }

    /// <summary>Check if x is (quote datum).</summary>
    private static bool IsQuoteForm(object x)
    {
        if (!Value.IsPair(x) || x == Value.NIL) return false;
        object car = Value.AsPair(x).car;
        if (Value.IsSymbol(car)) return Value.AsSymbol(car) == "quote";
        if (car is SyntaxObject stx && stx.IsIdentifier) return stx.SymbolName == "quote";
        return false;
    }

    /// <summary>Get identifier name from a possibly-wrapped object (for quasiquote keywords).</summary>
    private static string? GetQQName(object x)
    {
        if (x is SyntaxObject so && so.IsIdentifier) return so.SymbolName;
        if (Value.IsSymbol(x)) return Value.AsSymbol(x);
        return null;
    }

    /// <summary>Count elements in a list (for quasiquote).</summary>
    private static int QQListLength(object x)
    {
        int n = 0;
        object cur = x;
        while (true)
        {
            if (cur == Value.NIL || !Value.IsPair(cur)) return n;
            n++;
            cur = Value.AsPair(cur).cdr;
        }
    }

    private object ExpandApplication(SourcePos? pos, object form)
    {
        // Expand all sub-expressions
        var expanded = new List<object>();
        object cur = form;
        while (cur != Value.NIL)
        {
            if (!Value.IsPair(cur)) break;
            expanded.Add(ExpandForm(pos, Value.AsPair(cur).car));
            cur = Value.AsPair(cur).cdr;
        }
        return ((Pair)Pair.List(expanded.ToArray())).WithPos(pos);
    }

    // ---- Syntax Object Helpers ----

    /// <summary>Get the Nth element of a form.</summary>
    private static object FormNth(object form, int n)
    {
        object cur = form;
        for (int i = 0; i < n; i++)
        {
            if (!Value.IsPair(cur)) return Value.NIL;
            cur = Value.AsPair(cur).cdr;
        }
        if (!Value.IsPair(cur)) return Value.NIL;
        return Value.AsPair(cur).car;
    }

    /// <summary>Get the cdr from the Nth position of a form.</summary>
    private static object FormNthCdr(object form, int n)
    {
        object cur = form;
        for (int i = 0; i < n; i++)
        {
            if (!Value.IsPair(cur)) return Value.NIL;
            cur = Value.AsPair(cur).cdr;
        }
        return cur;
    }

    /// <summary>Count elements in a form.</summary>
    private static int FormLength(object form)
    {
        int n = 0;
        object cur = form;
        while (true)
        {
            if (!Value.IsPair(cur) || cur == Value.NIL) break;
            n++;
            cur = Value.AsPair(cur).cdr;
        }
        return n;
    }

    // ---- Helpers ----

    private static bool IsMacroPair(object obj)
    {
        return obj is MacroTransformer;
    }

    private static object ExtractTransformer(object macroPair)
    {
        return ((MacroTransformer)macroPair).Transformer;
    }
}
