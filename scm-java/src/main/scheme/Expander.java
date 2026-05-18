package scheme;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import scheme.primitives.PrimitiveDoImportSet;

/**
 * Sets-of-scopes macro expander. Performs a separate expansion pass before compilation.
 *
 * The expander:
 * 1. Wraps input S-expressions as syntax objects (only identifiers are wrapped)
 * 2. Expands all macros using the two-scope flip protocol (Flatt 2016)
 * 3. Processes define-syntax, let-syntax, letrec-syntax
 * 4. Handles define (both simple and function-shorthand)
 * 5. Handles internal definitions in lambda bodies
 * 6. Resolves all identifiers via the binding table
 * 7. Returns fully-expanded S-expressions with resolved names
 *
 * The output contains only core forms: if, lambda, set!, quote, begin, define, applications.
 * The compiler receives this output and produces bytecode without any macro handling.
 */
public class Expander {
    private final Modules modules;
    private final BindingTable bindingTable;

    public Expander(Modules modules) {
        this.modules = modules;
        this.bindingTable = modules.getBindingTable();
    }

    /**
     * Expand a top-level form. Returns fully-expanded S-expression.
     */
    public Object expand(SourcePos pos, Object form) {
        // Get the module scope and ensure bindings are registered
        int moduleScope = modules.getCurrentModuleScope();
        bindingTable.registerCoreFormBindings(moduleScope);

        // Wrap the input as syntax objects with module scope
        Object wrapped = SyntaxObject.wrapDatum(form, ScopeSet.of(moduleScope), pos);

        // Expand recursively
        Object expanded = expandForm(pos, wrapped);

        // Return expanded form — the compiler resolves identifiers
        // through their scope sets using BoundIdEq for locals and
        // the binding table for globals. No stripping needed.
        return expanded;
    }

    /**
     * Create a SyntaxObject for a core form keyword (lambda, define, etc.)
     * with the current module scope, so it resolves through the binding table.
     */
    private Object coreFormId(String name) {
        int moduleScope = modules.getCurrentModuleScope();
        return new SyntaxObject(Value.intern(name), ScopeSet.of(moduleScope), null);
    }

    // ---- Core Expansion ----

    /**
     * Recursively expand a form (syntax object or plain datum).
     */
    private Object expandForm(SourcePos pos, Object stx) {
        // Self-quoting constants: numbers, booleans, chars, strings, NIL
        if (stx == null || stx == Value.NIL) return stx;
        if (stx.equals(Value.T) || stx.equals(Value.F)) return stx;
        if (Value.isConstant(stx)) return stx;

        // Identifier (SyntaxObject wrapping a symbol)
        if (stx instanceof SyntaxObject && ((SyntaxObject) stx).isIdentifier()) {
            return expandIdentifier(pos, (SyntaxObject) stx);
        }

        // Plain symbol (no scopes)
        if (Value.isSymbol(stx)) {
            return stx; // Pass through as-is
        }

        // Must be a pair (list form) at this point
        if (!Value.isPair(stx)) return stx;
        Pair form = Value.asPair(stx);
        if (form.pos != null) pos = form.pos;

        // Get the operator (first element)
        Object first = form.car;
        String resolvedName = null;
        ResolvedBinding firstBinding = null;

        // Resolve the operator name
        if (first instanceof SyntaxObject && ((SyntaxObject) first).isIdentifier()) {
            SyntaxObject firstId = (SyntaxObject) first;
            firstBinding = SyntaxObject.resolve(firstId, bindingTable);
            if (firstBinding != null) {
                // Dispatch based on binding kind
                if (firstBinding.bindingKind == ResolvedBinding.Kind.CORE_FORM)
                    return expandCoreForm(pos, stx, firstBinding.symbolName);
                if (firstBinding.bindingKind == ResolvedBinding.Kind.MACRO)
                    return expandMacroCall(pos, stx, firstBinding.symbolName, firstBinding.value);
            }
            resolvedName = firstBinding != null ? firstBinding.symbolName : firstId.symbolName();
        } else if (Value.isSymbol(first)) {
            resolvedName = Value.asSymbol(first);
        }

        // Function call: expand all sub-expressions
        return expandApplication(pos, stx);
    }

    // ---- Identifier Resolution ----

    private Object expandIdentifier(SourcePos pos, SyntaxObject idStx) {
        // R7RS 4.1.1: "It is an error to reference or assign the value of a syntax keyword."
        ResolvedBinding binding = SyntaxObject.resolve(idStx, bindingTable);
        if (binding != null && binding.bindingKind == ResolvedBinding.Kind.CORE_FORM)
            throw new SchemeError(pos, "syntax keyword '~a' cannot be used as an expression",
                idStx.symbolName());
        // Return the SyntaxObject as-is — the compiler resolves identifiers
        // through their scope sets using BoundIdEq for local lookups
        // and the binding table for global lookups.
        return idStx;
    }

    /**
     * Dispatch to the appropriate core form expander.
     */
    private Object expandCoreForm(SourcePos pos, Object stx, String formName) {
        switch (formName) {
            case "quote":
                return ((Pair)Pair.list(coreFormId("quote"), SyntaxObject.strip(formNth(stx, 1)))).withPos(pos);

            case "quasiquote":
                return expandQuasiquote(pos, formNth(stx, 1));

            case "if":
                return expandIf(pos, stx);

            case "set!":
                return expandSet(pos, stx);

            case "begin":
                return expandBegin(pos, formNthCdr(stx, 1));

            case "lambda":
                return expandLambda(pos, stx);

            case "define":
                return expandDefine(pos, stx);

            case "define-syntax":
                return expandDefineSyntax(pos, stx, false);

            case "let":
                return expandLet(pos, stx);

            case "let*":
                return expandLetStar(pos, stx);

            case "letrec":
            case "letrec*":
                return expandLetrec(pos, stx, formName);

            case "let-syntax":
                return expandLetSyntax(pos, stx);

            case "letrec-syntax":
                return expandLetrecSyntax(pos, stx);

            case "cond-expand":
                return expandCondExpand(pos, stx);

            case "%primitive":
                // Resolve primitive at expansion time
                {
                    Object arg = SyntaxObject.strip(formNth(stx, 1));
                    // Unwrap (quote x) → x
                    if (Value.isPair(arg) && Value.isSymbol(Value.asPair(arg).car)
                        && Value.asSymbol(Value.asPair(arg).car).equals("quote"))
                        arg = Value.asPair(arg).second();
                    String name;
                    if (Value.isSymbol(arg))
                        name = Value.asSymbol(arg);
                    else
                        name = new String(Value.asString(arg));
                    Object primitive = modules.primitives.getPrimitive(pos, name);
                    return ((Pair)Pair.list(coreFormId("quote"), primitive)).withPos(pos);
                }

            case "import":
                // (import spec1 spec2 ...) — process each import set at expansion time
                return expandImport(pos, stx);

            case "define-library":
                return expandDefineLibrary(pos, stx);

            default:
                // Unknown core form — treat as application
                return expandApplication(pos, stx);
        }
    }

    // ---- Macro Expansion (Two-scope Flip Protocol) ----

    private Object expandMacroCall(SourcePos pos, Object form, String macroName,
                                   Object transformer) {
        if (!(transformer instanceof SyntaxRulesTransformer))
            throw new SchemeError(pos, "macro ~a: expected syntax-rules transformer", macroName);
        SyntaxRulesTransformer srt = (SyntaxRulesTransformer) transformer;

        // Two-scope flip protocol (Flatt 2016)
        int useSiteScope = SyntaxObject.freshScope();
        int introScope = SyntaxObject.freshScope();

        // Step 1: Add use-site scope and intro scope to input
        Object scopedInput = SyntaxObject.addScope(form, useSiteScope);
        scopedInput = SyntaxObject.addScope(scopedInput, introScope);

        // Extract args (cdr of scoped input)
        Object args;
        if (Value.isPair(scopedInput)) {
            args = Value.asPair(scopedInput).cdr;
        } else {
            args = Value.NIL;
        }

        Object result;
        try {
            result = srt.transformRaw(args, modules);
        } catch (SchemeError e) {
            throw new SchemeError(e, pos, "error in expansion of macro ~a", macroName);
        }

        // Step 2: Flip intro scope on output
        // Input identifiers (passed through template) have introScope, flip removes it.
        // Template identifiers don't have introScope, flip adds it.
        result = SyntaxObject.flipScope(result, introScope);

        // Step 3: Recurse
        return expandForm(pos, result);
    }

    // ---- Core Form Expansion ----

    private Object expandIf(SourcePos pos, Object form) {
        int len = formLength(form);
        Object test = expandForm(pos, formNth(form, 1));
        Object then = expandForm(pos, formNth(form, 2));
        Object alt = len >= 4 ? expandForm(pos, formNth(form, 3)) : new Values();
        return ((Pair)Pair.list(coreFormId("if"), test, then, alt)).withPos(pos);
    }

    private Object expandSet(SourcePos pos, Object form) {
        Object var = formNth(form, 1);
        // Keep the variable as-is (SyntaxObject) — stripping resolves it
        Object expr = expandForm(pos, formNth(form, 2));
        return ((Pair)Pair.list(coreFormId("set!"), var, expr)).withPos(pos);
    }

    /**
     * Expand a sequence of forms (begin body).
     * Handles define-syntax visibility: each define-syntax is processed before
     * expanding subsequent forms, making the macro available to later forms.
     */
    private Object expandBegin(SourcePos pos, Object forms) {
        if (forms == Value.NIL) return Value.NIL;

        ArrayList<Object> expandedForms = new ArrayList<>();
        Object current = forms;

        while (current != Value.NIL) {
            if (!Value.isPair(current)) break;

            Object form = Value.asPair(current).car;
            Object expanded = expandForm(pos, form);

            // After expanding, check if result is a begin — splice it
            if (Value.isPair(expanded) && Value.isSymbol(Value.asPair(expanded).car)
                && Value.asSymbol(Value.asPair(expanded).car).equals("begin")) {
                // Splice: add each sub-form
                Object inner = Value.asPair(expanded).cdr;
                while (inner != Value.NIL && Value.isPair(inner)) {
                    expandedForms.add(Value.asPair(inner).car);
                    inner = Value.asPair(inner).cdr;
                }
            } else {
                expandedForms.add(expanded);
            }

            current = Value.asPair(current).cdr;
        }

        if (expandedForms.size() == 0) return Value.NIL;
        if (expandedForms.size() == 1) return expandedForms.get(0);

        // Build (begin expanded1 expanded2 ...)
        Object result = Value.NIL;
        for (int i = expandedForms.size() - 1; i >= 0; i--)
            result = new Pair(expandedForms.get(i), result);
        return new Pair(coreFormId("begin"), result).withPos(pos);
    }

    private Object expandLambda(SourcePos pos, Object form) {
        Object parms = formNth(form, 1);
        Object body = formNthCdr(form, 2);

        // Sets-of-scopes protocol: generate a fresh scope for the binding context
        int scope = SyntaxObject.freshScope();

        // Add scope to parameters and body
        Object scopedParms = SyntaxObject.addScope(parms, scope);
        Object scopedBody = SyntaxObject.addScope(body, scope);

        // Register each parameter in the binding table
        registerParamBindings(scopedParms);

        Object expandedBody = expandBody(pos, scopedBody);

        return buildLambda(scopedParms, expandedBody, pos);
    }

    /**
     * Register each parameter from a parameter list in the binding table.
     * Handles proper lists, dotted lists, and single symbol rest parameters.
     */
    private void registerParamBindings(Object parms) {
        Object cur = parms;
        while (true) {
            if (cur instanceof SyntaxObject) {
                SyntaxObject stx = (SyntaxObject) cur;
                if (stx.isIdentifier()) {
                    // Rest parameter (dotted list tail or single symbol)
                    bindingTable.add(stx.symbolName(), stx.scopes,
                        ResolvedBinding.makeLocalRef(stx.symbolName(), stx));
                    return;
                }
                // Non-identifier SyntaxObject shouldn't happen in sets-of-scopes
                return;
            }
            if (cur == Value.NIL) return;
            if (Value.isSymbol(cur)) return; // Plain symbol rest parameter
            if (Value.isPair(cur)) {
                Object car = Value.asPair(cur).car;
                if (car instanceof SyntaxObject && ((SyntaxObject) car).isIdentifier()) {
                    SyntaxObject paramStx = (SyntaxObject) car;
                    bindingTable.add(paramStx.symbolName(), paramStx.scopes,
                        ResolvedBinding.makeLocalRef(paramStx.symbolName(), paramStx));
                }
                cur = Value.asPair(cur).cdr;
                continue;
            }
            return;
        }
    }

    /**
     * Expand a lambda/let body, handling internal definitions per R7RS 5.3.2.
     * Scans expanded forms for leading defines, collects them, and builds
     * a letrec* form. define-syntax is already handled by expandDefineSyntax
     * (which produces a (define name ...) form). begin forms are spliced.
     */
    private Object expandBody(SourcePos pos, Object body) {
        // Phase 1: partially expand forms to discover definitions.
        // Macros are expanded one step at a time (splicing begins,
        // evaluating define-syntax) until each form is classified as
        // a define or an expression. Forms are NOT fully expanded yet.
        ArrayList<Object> allForms = new ArrayList<>();
        Object current = body;
        while (current != Value.NIL) {
            if (!Value.isPair(current)) break;
            partialExpandBodyForm(pos, Value.asPair(current).car, allForms);
            current = Value.asPair(current).cdr;
        }

        // Phase 2: separate leading definitions from expressions (raw forms).
        // For defines, handle function shorthand (define (f args) body)
        // by converting to (define f (lambda ...)) before extracting name/expr.
        ArrayList<Object> defineNames = new ArrayList<>();
        ArrayList<Object> defineExprs = new ArrayList<>();
        ArrayList<Object> rawExpressions = new ArrayList<>();
        boolean inDefines = true;
        String docstring = null;

        for (Object form : allForms) {
            if (inDefines && isDefineForm(form)) {
                Object nameOrPair = getSecond(form);
                if (Value.isPair(nameOrPair)) {
                    // (define (f args...) body...) -> name = f, expr = (lambda (args...) body...)
                    Pair np = Value.asPair(nameOrPair);
                    defineNames.add(np.car);
                    Object args = np.cdr;
                    Object defBody = formNthCdr(form, 2);
                    ArrayList<Object> lambdaParts = new ArrayList<>();
                    lambdaParts.add(coreFormId("lambda"));
                    lambdaParts.add(args);
                    Object cur = defBody;
                    while (cur != Value.NIL && Value.isPair(cur)) {
                        lambdaParts.add(Value.asPair(cur).car);
                        cur = Value.asPair(cur).cdr;
                    }
                    defineExprs.add(Pair.list(lambdaParts.toArray()));
                } else {
                    // (define name expr)
                    defineNames.add(nameOrPair);
                    defineExprs.add(formLength(form) >= 3 ? getThird(form) : Value.NIL);
                }
            } else if (inDefines && form instanceof char[] && rawExpressions.size() == 0 && defineNames.size() == 0) {
                docstring = new String((char[]) form);
            } else {
                if (inDefines) inDefines = false;
                rawExpressions.add(form);
            }
        }

        // Validate: no defines after expressions
        for (Object expr : rawExpressions) {
            if (isDefineForm(expr))
                throw new SchemeError(pos,
                    "define not allowed here: internal definitions must precede all expressions in a body");
        }

        // Phase 3: if no defines, just expand all forms and return
        if (defineNames.size() == 0) {
            ArrayList<Object> expandedForms = new ArrayList<>();
            if (docstring != null)
                expandedForms.add(docstring.toCharArray());
            List<Object> source = rawExpressions.size() > 0 ? rawExpressions : allForms;
            for (Object form : source)
                expandedForms.add(expandForm(pos, form));
            Object result = Value.NIL;
            for (int i = expandedForms.size() - 1; i >= 0; i--)
                result = new Pair(expandedForms.get(i), result);
            return result;
        }

        // Phase 4: create letrec* scope, add it to ALL forms, register
        // define names, THEN expand everything with the scope in place.
        // This follows the sets-of-scopes algorithm: the letrec* scope
        // is established first so that all names are visible during
        // expansion of both init expressions and body expressions.
        int letrecScope = SyntaxObject.freshScope();

        // Add scope to all define names and register them
        ArrayList<Object> scopedNames = new ArrayList<>();
        for (int i = 0; i < defineNames.size(); i++) {
            Object scopedName = SyntaxObject.addScope(defineNames.get(i), letrecScope);
            scopedNames.add(scopedName);
            if (scopedName instanceof SyntaxObject && ((SyntaxObject) scopedName).isIdentifier()) {
                SyntaxObject varStx = (SyntaxObject) scopedName;
                bindingTable.add(varStx.symbolName(), varStx.scopes,
                    ResolvedBinding.makeLocalRef(varStx.symbolName(), varStx));
            }
        }

        // Add scope to init expressions, expand them, then re-add scope.
        // The re-add ensures that template-introduced identifiers from macros
        // expanded during this phase also carry the letrec* scope, enabling
        // forward references through macros. AddScope is idempotent.
        ArrayList<Object> scopedBindingPairs = new ArrayList<>();
        for (int i = 0; i < defineNames.size(); i++) {
            Object scopedExpr = SyntaxObject.addScope(defineExprs.get(i), letrecScope);
            Object expandedExpr = expandForm(pos, scopedExpr);
            expandedExpr = SyntaxObject.addScope(expandedExpr, letrecScope);
            scopedBindingPairs.add(Pair.list(scopedNames.get(i), expandedExpr));
        }

        // Add scope to body expressions, expand them, then re-add scope
        ArrayList<Object> scopedExpressions = new ArrayList<>();
        for (Object expr : rawExpressions) {
            Object scopedExpr = SyntaxObject.addScope(expr, letrecScope);
            Object expandedExpr = expandForm(pos, scopedExpr);
            scopedExpressions.add(SyntaxObject.addScope(expandedExpr, letrecScope));
        }
        if (scopedExpressions.size() == 0)
            scopedExpressions.add(Value.NIL);

        // Produce the (letrec* ...) form directly for the compiler
        ArrayList<Object> letrecParts = new ArrayList<>();
        letrecParts.add(coreFormId("letrec*"));
        letrecParts.add(Pair.list(scopedBindingPairs.toArray()));
        letrecParts.addAll(scopedExpressions);
        Object expandedLetrec = Pair.list(letrecParts.toArray());

        // Return body with docstring OUTSIDE the letrec so CompLambda can detect it
        if (docstring != null)
            return new Pair(docstring.toCharArray(), new Pair(expandedLetrec, Value.NIL));
        return new Pair(expandedLetrec, Value.NIL);
    }

    /**
     * Partially expand a body form to discover definitions.
     * Macros are expanded one step at a time using only the intro scope
     * (no use-site scope). This ensures pass-through identifiers in
     * macro-generated definitions retain their original scopes.
     * Full expansion (with use-site scopes) happens later in Phase 4.
     */
    private void partialExpandBodyForm(SourcePos pos, Object form, ArrayList<Object> results) {
        while (true) {
            if (!Value.isPair(form) || form == Value.NIL) {
                results.add(form);
                return;
            }

            Pair formPair = Value.asPair(form);
            if (formPair.pos != null) pos = formPair.pos;
            Object head = formPair.car;

            if (head instanceof SyntaxObject && ((SyntaxObject) head).isIdentifier()) {
                SyntaxObject headStx = (SyntaxObject) head;
                ResolvedBinding headBinding = SyntaxObject.resolve(headStx, bindingTable);

                if (headBinding != null) {
                    if (headBinding.bindingKind == ResolvedBinding.Kind.CORE_FORM) {
                        switch (headBinding.symbolName) {
                            case "define":
                                results.add(form);
                                return;

                            case "define-syntax":
                                results.add(expandDefineSyntax(pos, form, true));
                                return;

                            case "begin": {
                                Object subForms = getCdr(form);
                                while (subForms != Value.NIL && Value.isPair(subForms)) {
                                    partialExpandBodyForm(pos, Value.asPair(subForms).car, results);
                                    subForms = Value.asPair(subForms).cdr;
                                }
                                return;
                            }

                            case "let-syntax":
                            case "letrec-syntax": {
                                Object expanded = "let-syntax".equals(headBinding.symbolName)
                                    ? expandLetSyntax(pos, form)
                                    : expandLetrecSyntax(pos, form);
                                if (isBeginForm(expanded)) {
                                    Object beginBody = getCdr(expanded);
                                    while (beginBody != Value.NIL && Value.isPair(beginBody)) {
                                        partialExpandBodyForm(pos,
                                            Value.asPair(beginBody).car, results);
                                        beginBody = Value.asPair(beginBody).cdr;
                                    }
                                } else {
                                    partialExpandBodyForm(pos, expanded, results);
                                }
                                return;
                            }

                            default:
                                results.add(form);
                                return;
                        }
                    }

                    if (headBinding.bindingKind == ResolvedBinding.Kind.MACRO) {
                        if (!(headBinding.value instanceof SyntaxRulesTransformer)) {
                            results.add(form);
                            return;
                        }
                        SyntaxRulesTransformer srt = (SyntaxRulesTransformer) headBinding.value;

                        // Expand one macro step with intro scope only (no use-site scope)
                        int introScope = SyntaxObject.freshScope();

                        Object scopedInput = SyntaxObject.addScope(form, introScope);

                        Object args = Value.isPair(scopedInput)
                            ? Value.asPair(scopedInput).cdr : Value.NIL;

                        Object result;
                        try { result = srt.transformRaw(args, modules); }
                        catch (SchemeError e) {
                            throw new SchemeError(e, pos,
                                "error in expansion of macro ~a", headBinding.symbolName);
                        }

                        result = SyntaxObject.flipScope(result, introScope);

                        form = result;
                        continue;
                    }
                }
            } else if (Value.isSymbol(head)) {
                String symName = Value.asSymbol(head);
                if ("define".equals(symName) || "define-syntax".equals(symName)) {
                    results.add(form);
                    return;
                }
                if ("begin".equals(symName)) {
                    Object subForms = getCdr(form);
                    while (subForms != Value.NIL && Value.isPair(subForms)) {
                        partialExpandBodyForm(pos, Value.asPair(subForms).car, results);
                        subForms = Value.asPair(subForms).cdr;
                    }
                    return;
                }
            }

            // Not a define, begin, or macro — it's an expression
            results.add(form);
            return;
        }
    }

    /** Check if a form is (define ...) */
    private static boolean isDefineForm(Object form) {
        if (!Value.isPair(form) || form == Value.NIL) return false;
        Object head = Value.asPair(form).car;
        if (Value.isSymbol(head)) return "define".equals(Value.asSymbol(head));
        if (head instanceof SyntaxObject && ((SyntaxObject) head).isIdentifier())
            return ((SyntaxObject) head).symbolName().equals("define");
        return false;
    }

    /** Check if a form is (begin ...) */
    private static boolean isBeginForm(Object form) {
        if (!Value.isPair(form) || form == Value.NIL) return false;
        Object head = Value.asPair(form).car;
        if (Value.isSymbol(head)) return "begin".equals(Value.asSymbol(head));
        if (head instanceof SyntaxObject && ((SyntaxObject) head).isIdentifier())
            return ((SyntaxObject) head).symbolName().equals("begin");
        return false;
    }

    /** Get cdr of a form. */
    private static Object getCdr(Object form) {
        return Value.asPair(form).cdr;
    }

    /** Get second element (car of cdr). */
    private static Object getSecond(Object form) {
        Object cdr = Value.asPair(form).cdr;
        return Value.asPair(cdr).car;
    }

    /** Get third element. */
    private static Object getThird(Object form) {
        Object cdr = Value.asPair(form).cdr;
        Object cddr = Value.asPair(cdr).cdr;
        return Value.asPair(cddr).car;
    }

    private Object buildLambda(Object parms, Object body, SourcePos pos) {
        ArrayList<Object> elements = new ArrayList<>();
        elements.add(coreFormId("lambda"));
        elements.add(parms);
        Object cur = body;
        while (cur != Value.NIL && Value.isPair(cur)) {
            elements.add(Value.asPair(cur).car);
            cur = Value.asPair(cur).cdr;
        }
        return ((Pair)Pair.list(elements.toArray())).withPos(pos);
    }

    /**
     * Expand a define form.
     * (define x expr) -> (define x expanded-expr)
     * (define (f args...) body...) -> (define f (lambda (args...) expanded-body...))
     */
    private Object expandDefine(SourcePos pos, Object form) {
        Object nameOrPair = formNth(form, 1);

        if (Value.isPair(nameOrPair)) {
            // (define (f args...) body...) -> (define f (lambda (args...) body...))
            Pair np = Value.asPair(nameOrPair);
            // Keep name as SyntaxObject for hygiene
            Object name = np.car;
            Object args = np.cdr;
            Object body = formNthCdr(form, 2);
            // Build a lambda form and expand it through expandLambda
            // so that scope marks are properly applied.
            ArrayList<Object> lambdaParts = new ArrayList<>();
            lambdaParts.add(coreFormId("lambda"));
            lambdaParts.add(args);
            Object cur = body;
            while (cur != Value.NIL && Value.isPair(cur)) {
                lambdaParts.add(Value.asPair(cur).car);
                cur = Value.asPair(cur).cdr;
            }
            Object lambdaForm = Pair.list(lambdaParts.toArray());
            Object expandedLambda = expandLambda(pos, lambdaForm);

            // Register top-level define in binding table so subsequent macros
            // whose templates reference this name can resolve it
            registerTopLevelDefine(name);

            return ((Pair)Pair.list(coreFormId("define"), name, expandedLambda)).withPos(pos);
        } else {
            // (define name expr) — keep name as SyntaxObject for hygiene
            Object name = nameOrPair;
            Object expr = formNth(form, 2);
            Object expandedExpr = expandForm(pos, expr);

            // Register top-level define in binding table
            registerTopLevelDefine(name);

            return ((Pair)Pair.list(coreFormId("define"), name, expandedExpr)).withPos(pos);
        }
    }

    /**
     * Register a top-level define in the binding table so that macro templates
     * referencing this name can resolve it during expansion.
     */
    private void registerTopLevelDefine(Object name) {
        String symName;
        if (name instanceof SyntaxObject && ((SyntaxObject) name).isIdentifier())
            symName = ((SyntaxObject) name).symbolName();
        else if (Value.isSymbol(name))
            symName = Value.asSymbol(name);
        else
            return;

        int moduleScope = modules.getCurrentModuleScope();
        String moduleName = modules.getCurrentModule().getName();
        String originModule = moduleName;
        bindingTable.add(symName, ScopeSet.of(moduleScope),
            new ResolvedBinding(
                ResolvedBinding.Kind.GLOBAL,
                originModule + ":" + symName,
                moduleName, symName, symName, null));
    }

    /**
     * Expand (let ((var val) ...) body ...) and (let name ((var val) ...) body ...)
     * These are core forms handled directly by the Compiler.
     */
    private Object expandLet(SourcePos pos, Object form) {
        Object second = formNth(form, 1);

        boolean isNamed = (second instanceof SyntaxObject && ((SyntaxObject) second).isIdentifier())
                       || (Value.isSymbol(second) && !Value.isPair(second));

        if (isNamed) {
            // Named let: (let name ((var val) ...) body ...)
            Object name = second;
            Object bindings = formNth(form, 2);
            Object body = formNthCdr(form, 3);

            // Expand values in outer scope
            Object expandedBindings = expandBindings(pos, bindings);

            // Sets-of-scopes protocol
            int scope = SyntaxObject.freshScope();
            Object scopedBindings = scopeBindingVars(expandedBindings, scope);
            Object scopedBody = SyntaxObject.addScope(body, scope);

            // Scope the loop name too
            Object scopedName = SyntaxObject.addScope(name, scope);
            if (scopedName instanceof SyntaxObject && ((SyntaxObject) scopedName).isIdentifier()) {
                SyntaxObject nameStx = (SyntaxObject) scopedName;
                bindingTable.add(nameStx.symbolName(), nameStx.scopes,
                    ResolvedBinding.makeLocalRef(nameStx.symbolName(), nameStx));
            }

            // Register binding variables
            registerBindingVarBindings(scopedBindings);

            Object expandedBody = expandBody(pos, scopedBody);

            ArrayList<Object> parts = new ArrayList<>();
            parts.add(coreFormId("let"));
            parts.add(scopedName);
            parts.add(scopedBindings);
            appendList(parts, expandedBody);
            return ((Pair)Pair.list(parts.toArray())).withPos(pos);
        } else {
            // Simple let: (let ((var val) ...) body ...)
            Object bindings = second;
            Object body = formNthCdr(form, 2);

            // Expand values in outer scope
            Object expandedBindings = expandBindings(pos, bindings);

            // Sets-of-scopes protocol
            int scope = SyntaxObject.freshScope();
            Object scopedBindings = scopeBindingVars(expandedBindings, scope);
            Object scopedBody = SyntaxObject.addScope(body, scope);

            // Register binding variables
            registerBindingVarBindings(scopedBindings);

            Object expandedBody = expandBody(pos, scopedBody);

            ArrayList<Object> parts = new ArrayList<>();
            parts.add(coreFormId("let"));
            parts.add(scopedBindings);
            appendList(parts, expandedBody);
            return ((Pair)Pair.list(parts.toArray())).withPos(pos);
        }
    }

    /**
     * Add scope to each variable in an expanded binding list ((var val) ...),
     * and return the binding list with scoped variables.
     */
    private Object scopeBindingVars(Object bindings, int scope) {
        ArrayList<Object> result = new ArrayList<>();
        Object cur = bindings;
        while (cur != Value.NIL && Value.isPair(cur)) {
            Object binding = Value.asPair(cur).car;
            if (Value.isPair(binding)) {
                Object var = Value.asPair(binding).car;
                Object val = Value.asPair(Value.asPair(binding).cdr).car;
                Object scopedVar = SyntaxObject.addScope(var, scope);
                result.add(Pair.list(scopedVar, val));
            } else {
                result.add(binding);
            }
            cur = Value.asPair(cur).cdr;
        }
        return Pair.list(result.toArray());
    }

    /**
     * Register binding variables from an already-scoped binding list in the binding table.
     */
    private void registerBindingVarBindings(Object bindings) {
        Object cur = bindings;
        while (cur != Value.NIL && Value.isPair(cur)) {
            Object binding = Value.asPair(cur).car;
            if (Value.isPair(binding)) {
                Object var = Value.asPair(binding).car;
                if (var instanceof SyntaxObject && ((SyntaxObject) var).isIdentifier()) {
                    SyntaxObject varStx = (SyntaxObject) var;
                    bindingTable.add(varStx.symbolName(), varStx.scopes,
                        ResolvedBinding.makeLocalRef(varStx.symbolName(), varStx));
                }
            }
            cur = Value.asPair(cur).cdr;
        }
    }

    /** Expand (let* ((var val) ...) body ...) */
    private Object expandLetStar(SourcePos pos, Object form) {
        Object bindings = formNth(form, 1);
        Object body = formNthCdr(form, 2);
        return expandLetStarAsNestedLets(pos, bindings, body);
    }

    /**
     * Expand (let* ((v1 e1) (v2 e2) ...) body...) by directly handling
     * scoping for each binding sequentially. Each binding gets a fresh scope
     * that is visible to subsequent bindings and the body.
     * Returns nested (let ...) forms for the compiler.
     */
    private Object expandLetStarAsNestedLets(SourcePos pos, Object bindings, Object body) {
        if (bindings == Value.NIL || !Value.isPair(bindings)) {
            // No bindings left — expand body
            Object expandedBody = expandBody(pos, body);
            return wrapBegin(expandedBody);
        }

        // Take first binding
        Object firstBinding = Value.asPair(bindings).car;
        Object restBindings = Value.asPair(bindings).cdr;

        // Expand the init expression in the current scope
        Object var = Value.asPair(firstBinding).car;
        Object initExpr = Value.isPair(Value.asPair(firstBinding).cdr)
            ? Value.asPair(Value.asPair(firstBinding).cdr).car
            : Value.F;
        Object expandedInit = expandForm(pos, initExpr);

        // Fresh scope for this binding
        int scope = SyntaxObject.freshScope();
        Object scopedVar = SyntaxObject.addScope(var, scope);

        // Register the binding in the binding table
        if (scopedVar instanceof SyntaxObject && ((SyntaxObject) scopedVar).isIdentifier()) {
            SyntaxObject varStx = (SyntaxObject) scopedVar;
            bindingTable.add(varStx.symbolName(), varStx.scopes,
                ResolvedBinding.makeLocalRef(varStx.symbolName(), varStx));
        }

        // Add scope to remaining bindings and body
        Object scopedRestBindings = SyntaxObject.addScope(restBindings, scope);
        Object scopedBody = SyntaxObject.addScope(body, scope);

        // Recursively expand remaining bindings
        Object inner = expandLetStarAsNestedLets(pos, scopedRestBindings, scopedBody);

        // Build (let ((var init)) inner) for the compiler
        Object expandedBinding = Pair.list(scopedVar, expandedInit);
        return ((Pair)Pair.list(coreFormId("let"), Pair.list(expandedBinding), inner)).withPos(pos);
    }

    /**
     * Wrap a list of expanded body forms as a single expression.
     * Single form: return as-is. Multiple: wrap in (begin ...).
     */
    private Object wrapBegin(Object forms) {
        if (forms == Value.NIL) return Value.F;
        if (!Value.isPair(forms)) return forms;
        if (Value.asPair(forms).cdr == Value.NIL)
            return Value.asPair(forms).car; // single form
        return new Pair(coreFormId("begin"), forms);
    }

    /** Expand (letrec ((var val) ...) body ...) or (letrec* ...) */
    private Object expandLetrec(SourcePos pos, Object form, String name) {
        Object bindings = formNth(form, 1);
        Object body = formNthCdr(form, 2);
        return expandLetRecCommon(pos, bindings, body, name);
    }

    /**
     * Common expansion for letrec, letrec*: values can reference bindings,
     * so the scope is applied to BOTH bindings and body.
     */
    private Object expandLetRecCommon(SourcePos pos, Object bindings, Object body, String name) {
        int scope = SyntaxObject.freshScope();

        // Add scope to both bindings and body
        Object scopedBindings = SyntaxObject.addScope(bindings, scope);
        Object scopedBody = SyntaxObject.addScope(body, scope);

        // Register binding variables in the binding table
        registerRawBindingVarBindings(scopedBindings);

        Object expandedBindings = expandBindings(pos, scopedBindings);
        Object expandedBody = expandBody(pos, scopedBody);

        ArrayList<Object> parts = new ArrayList<>();
        parts.add(coreFormId(name));
        parts.add(expandedBindings);
        appendList(parts, expandedBody);
        return ((Pair)Pair.list(parts.toArray())).withPos(pos);
    }

    /**
     * Register binding variables from a raw (not yet expanded) scoped binding list.
     */
    private void registerRawBindingVarBindings(Object bindings) {
        Object cur = bindings;
        while (cur != Value.NIL && Value.isPair(cur)) {
            Object binding = Value.asPair(cur).car;
            if (Value.isPair(binding)) {
                Object var = Value.asPair(binding).car;
                if (var instanceof SyntaxObject && ((SyntaxObject) var).isIdentifier()) {
                    SyntaxObject varStx = (SyntaxObject) var;
                    bindingTable.add(varStx.symbolName(), varStx.scopes,
                        ResolvedBinding.makeLocalRef(varStx.symbolName(), varStx));
                }
            }
            cur = Value.asPair(cur).cdr;
        }
    }

    /** Expand binding list ((var val) ...) — expand each val expression. */
    private Object expandBindings(SourcePos pos, Object bindings) {
        ArrayList<Object> result = new ArrayList<>();
        Object cur = bindings;
        while (cur != Value.NIL) {
            if (!Value.isPair(cur)) break;
            Object binding = Value.asPair(cur).car;
            if (Value.isPair(binding)) {
                Object var = Value.asPair(binding).car;
                Object valExpr = Value.NIL;
                Object bindCdr = Value.asPair(binding).cdr;
                if (Value.isPair(bindCdr))
                    valExpr = Value.asPair(bindCdr).car;
                Object expandedVal = expandForm(pos, valExpr);
                result.add(Pair.list(var, expandedVal));
            } else {
                result.add(binding);
            }
            cur = Value.asPair(cur).cdr;
        }
        return Pair.list(result.toArray());
    }

    /** Append elements from a Pair list to a Java list. */
    private static void appendList(ArrayList<Object> target, Object pairList) {
        Object cur = pairList;
        while (cur != Value.NIL && Value.isPair(cur)) {
            target.add(Value.asPair(cur).car);
            cur = Value.asPair(cur).cdr;
        }
    }

    /**
     * Expand define-syntax: evaluate the transformer, bind it as a macro,
     * and produce a runtime binding for the module system.
     */
    private Object expandDefineSyntax(SourcePos pos, Object form, boolean inBodyContext) {
        // In body contexts (let/lambda bodies), the name carries body scopes that
        // prevent the macro from leaking into the global scope. At the top level,
        // macro-generated define-syntax may have intro/use-site scopes on the name
        // that should NOT restrict visibility -- use moduleScope only.
        Object nameObj = formNth(form, 1);
        int moduleScope = modules.getCurrentModuleScope();
        ScopeSet macroScopes;
        if (inBodyContext && nameObj instanceof SyntaxObject && ((SyntaxObject) nameObj).isIdentifier()) {
            macroScopes = ((SyntaxObject) nameObj).scopes;
            nameObj = ((SyntaxObject) nameObj).symbolName();
        } else {
            if (nameObj instanceof SyntaxObject && ((SyntaxObject) nameObj).isIdentifier())
                nameObj = ((SyntaxObject) nameObj).symbolName();
            macroScopes = ScopeSet.of(moduleScope);
        }
        String name = Value.asSymbol(nameObj);

        int len = formLength(form);
        Object transformerExpr = (len == 4) ? formNth(form, 3) : formNth(form, 2);

        // Evaluate the transformer expression
        Object transformer = evalTransformerInExpander(pos, transformerExpr);

        // Build macro binding
        String docstring = (len == 4) ? new String(Value.asString(SyntaxObject.strip(formNth(form, 2)))) : null;
        Object macroPair = new MacroTransformer(transformer, docstring);

        // Only store in module bindings at module level (no extra body scopes).
        // Inside let/lambda bodies, the macro should be scoped -- not globally visible.
        if (macroScopes.setEquals(ScopeSet.of(moduleScope)))
            modules.getCurrentModule().bind(name, macroPair);

        // Register in the binding table with the name's actual scopes
        bindingTable.add(name, macroScopes,
            ResolvedBinding.makeMacro(modules.getCurrentModule().getName(), name, transformer));

        // Produce a define form for the runtime so the binding persists
        // and doesn't break internal-definition scanning in lambda bodies.
        // Use a plain symbol for the variable -- this define is an implementation
        // detail for the module system, not a user-visible binding that participates
        // in scope-based resolution.
        return ((Pair)Pair.list(coreFormId("define"), Value.intern(name),
            Pair.list(coreFormId("quote"), macroPair))).withPos(pos);
    }

    /** Evaluate a transformer expression. Must be (syntax-rules ...). */
    private Object evalTransformerInExpander(SourcePos pos, Object expr) {
        if (Value.isPair(expr)) {
            Object head = Value.asPair(expr).car;
            String headName = null;
            if (head instanceof SyntaxObject && ((SyntaxObject) head).isIdentifier())
                headName = ((SyntaxObject) head).symbolName();
            else if (Value.isSymbol(head))
                headName = Value.asSymbol(head);
            if ("syntax-rules".equals(headName)) {
                return SyntaxRulesTransformer.parse(
                    Value.asPair(expr).cdr,
                    modules.getCurrentModule().getName(),
                    modules,
                    null);
            }
        }

        throw new SchemeError(pos, "define-syntax: expected (syntax-rules ...) transformer");
    }

    private Object expandLetSyntax(SourcePos pos, Object form) {
        Object bindings = formNth(form, 1);  // the bindings list
        Object body = formNthCdr(form, 2);   // the body forms

        // Evaluate each transformer and bind macros
        // Use a fresh scope for the let-syntax body so these macros
        // are visible only within the body
        int scope = SyntaxObject.freshScope();

        Object b = bindings;
        while (b != Value.NIL && Value.isPair(b)) {
            Object binding = Value.asPair(b).car;
            if (!Value.isPair(binding)) { b = Value.asPair(b).cdr; continue; }
            Pair bp = Value.asPair(binding);
            Object nameObj = bp.first();
            // Add the fresh scope to the name identifier so its scopes
            // match what body identifiers will carry (preserves cross-module scopes)
            nameObj = SyntaxObject.addScope(nameObj, scope);
            ScopeSet macroScopes;
            String name;
            if (nameObj instanceof SyntaxObject && ((SyntaxObject) nameObj).isIdentifier()) {
                name = ((SyntaxObject) nameObj).symbolName();
                macroScopes = ((SyntaxObject) nameObj).scopes;
            } else {
                name = Value.asSymbol(nameObj);
                macroScopes = ScopeSet.of(modules.getCurrentModuleScope()).add(scope);
            }
            Object bpCdr = bp.cdr;
            Object transformerExpr = Value.isPair(bpCdr) ? Value.asPair(bpCdr).car : Value.NIL;
            Object transformer = evalTransformerInExpander(pos, transformerExpr);

            // Register in binding table with scopes from the name identifier
            bindingTable.add(name, macroScopes,
                ResolvedBinding.makeMacro(modules.getCurrentModule().getName(), name, transformer));

            b = Value.asPair(b).cdr;
        }

        // Add the let-syntax scope to the body
        Object scopedBody = SyntaxObject.addScope(body, scope);

        // Expand the body as a begin
        return expandBegin(pos, scopedBody);
    }

    private Object expandLetrecSyntax(SourcePos pos, Object form) {
        Object bindings = formNth(form, 1);
        Object body = formNthCdr(form, 2);

        int scope = SyntaxObject.freshScope();
        String moduleName = modules.getCurrentModule().getName();

        // Add scope to bindings so template identifiers carry the letrec scope
        // (analogous to expandLetRecCommon scoping bindings before expansion)
        Object scopedBindings = SyntaxObject.addScope(bindings, scope);

        // Pass 1: parse all transformers and collect (name, scopes, transformer) triples
        List<String> names = new ArrayList<>();
        List<ScopeSet> scopeSets = new ArrayList<>();
        List<Object> transformers = new ArrayList<>();
        Object b = scopedBindings;
        while (b != Value.NIL && Value.isPair(b)) {
            Object binding = Value.asPair(b).car;
            if (Value.isPair(binding)) {
                Pair bp = Value.asPair(binding);
                Object nameObj = bp.first();
                // Use the identifier's actual scopes (which include the fresh scope
                // from scopedBindings and any cross-module expansion scopes)
                ScopeSet macroScopes;
                String name;
                if (nameObj instanceof SyntaxObject && ((SyntaxObject) nameObj).isIdentifier()) {
                    name = ((SyntaxObject) nameObj).symbolName();
                    macroScopes = ((SyntaxObject) nameObj).scopes;
                } else {
                    name = Value.asSymbol(nameObj);
                    macroScopes = ScopeSet.of(modules.getCurrentModuleScope()).add(scope);
                }
                Object bpCdr = bp.cdr;
                Object transformerExpr = Value.isPair(bpCdr) ? Value.asPair(bpCdr).car : Value.NIL;
                Object transformer = evalTransformerInExpander(pos, transformerExpr);
                names.add(name);
                scopeSets.add(macroScopes);
                transformers.add(transformer);
            }
            b = Value.asPair(b).cdr;
        }

        // Pass 2: register all bindings in binding table at once
        for (int i = 0; i < names.size(); i++) {
            String name = names.get(i);
            ScopeSet macroScopes = scopeSets.get(i);
            Object transformer = transformers.get(i);
            bindingTable.add(name, macroScopes,
                ResolvedBinding.makeMacro(moduleName, name, transformer));
        }

        // Add scope to body and expand
        Object scopedBody = SyntaxObject.addScope(body, scope);
        return expandBegin(pos, scopedBody);
    }

    /**
     * Process a single import set: load the module, register bindings in both
     * Module.bindings (for VM runtime) and the binding table (for expansion/compilation).
     */
    void doImportSet(SourcePos pos, Object importSpec) {
        PrimitiveDoImportSet importer = (PrimitiveDoImportSet) modules.primitives.getPrimitive("%do-import-set");
        ImportResult importResult = importer.doImportSet(pos, importSpec);
        Module module = modules.getCurrentModule();
        int modScope = modules.getCurrentModuleScope();
        ScopeSet scopeSet = ScopeSet.of(modScope);

        for (java.util.Map.Entry<String, Cell> kv : importResult.bindings.entrySet()) {
            String name = kv.getKey();
            Cell cell = kv.getValue();
            Object value = cell.value;
            String origin = importResult.provenance.get(name);

            // Register in Module.bindings for VM runtime (shares the cell)
            module.importBinding(pos, name, cell, origin);

            // Core form markers don't need binding table registration —
            // registerCoreFormBindings handles that per module scope
            if (value instanceof CoreFormMarker) continue;

            // Register directly in binding table for expander/compiler
            ResolvedBinding binding;
            if (value instanceof MacroTransformer) {
                MacroTransformer mt = (MacroTransformer) value;
                binding = new ResolvedBinding(
                    ResolvedBinding.Kind.MACRO,
                    origin + ":" + name,
                    module.getName(), name, name,
                    mt.transformer);
            } else {
                binding = new ResolvedBinding(
                    ResolvedBinding.Kind.GLOBAL,
                    origin + ":" + name,
                    module.getName(), name, name, null);
            }
            bindingTable.add(name, scopeSet, binding);
        }
    }

    /**
     * Expand (import spec1 spec2 ...) — process each import set at expansion time.
     * All work is done during expansion; returns a no-op form for the compiler.
     */
    private Object expandImport(SourcePos pos, Object stx) {
        Object specs = formNthCdr(stx, 1);
        while (specs != Value.NIL) {
            Object spec = SyntaxObject.strip(Value.asPair(specs).car);
            try {
                doImportSet(pos, spec);
            } catch (SchemeError e) {
                throw new SchemeError(e, "Failed to import ~a", spec);
            } catch (Exception e) {
                throw new SchemeError("Failed to import ~a", spec);
            }
            specs = Value.asPair(specs).cdr;
        }
        // All import work is done at expansion time; return a no-op for the compiler
        return ((Pair)Pair.list(coreFormId("begin"))).withPos(pos);
    }

    /**
     * Expand (define-library (name ...) decl ...) — process library declarations
     * at expansion time. Handles export, import, begin, include, include-ci,
     * include-library-declarations, and cond-expand clauses.
     */
    private Object expandDefineLibrary(SourcePos pos, Object stx) {
        Object moduleDecl = SyntaxObject.strip(formNth(stx, 1));
        String moduleName = Modules.asModuleName(moduleDecl);

        String originalName = modules.getCurrentModule().getName();
        modules.setCurrentModule(moduleName);
        Module module = modules.getCurrentModule();

        // Register core form bindings for the new module scope
        int modScope = modules.getCurrentModuleScope();
        bindingTable.registerCoreFormBindings(modScope);

        java.util.List<Object> exports = new java.util.ArrayList<>();

        try {
            Object decls = formNthCdr(stx, 2);
            processLibraryDeclarations(pos, decls, module, exports);

            // Register exports
            for (Object symbol : exports) {
                if (Value.isPair(symbol)) {
                    // (rename src dest)
                    Pair renamePair = Value.asPair(Value.asPair(symbol).cdr);
                    String src = Value.asSymbol(renamePair.car);
                    String dest = Value.asSymbol(Value.asPair(renamePair.cdr).car);
                    module.export(src, dest);
                } else {
                    module.export((String) symbol);
                }
            }
        } finally {
            modules.setCurrentModule(originalName);
        }

        // All work done at expansion time; return the module name as a quoted value
        return ((Pair)Pair.list(coreFormId("quote"), moduleDecl)).withPos(pos);
    }

    /**
     * Process a sequence of library declarations (export, import, begin, include, etc.).
     */
    private void processLibraryDeclarations(SourcePos pos, Object decls, Module module, java.util.List<Object> exports) {
        while (decls != Value.NIL) {
            Object decl = SyntaxObject.strip(Value.asPair(decls).car);
            processLibraryDeclaration(pos, Value.asPair(decl), module, exports);
            decls = Value.asPair(decls).cdr;
        }
    }

    /**
     * Process a single library declaration.
     */
    private void processLibraryDeclaration(SourcePos pos, Pair current, Module module, java.util.List<Object> exports) {
        Object what = current.car;
        Object val = current.cdr;
        IEvaluator evaluator = modules.evaluator;

        if (what.equals("export")) {
            Pair.appendToList(val, exports);
        } else if (what.equals("import")) {
            Object specs = val;
            while (specs != Value.NIL && Value.isPair(specs)) {
                try {
                    doImportSet(pos, Value.asPair(specs).car);
                } catch (SchemeError e) {
                    throw new SchemeError(e, "Failed to import ~a", Value.asPair(specs).car);
                } catch (Exception e) {
                    throw new SchemeError("Failed to import ~a", Value.asPair(specs).car);
                }
                specs = Value.asPair(specs).cdr;
            }
        } else if (what.equals("include")) {
            Object filenames = val;
            while (filenames != Value.NIL && Value.isPair(filenames)) {
                String filename = new String(Value.asString(Value.asPair(filenames).car));
                evaluator.evalFile(new java.io.File(filename));
                filenames = Value.asPair(filenames).cdr;
            }
        } else if (what.equals("include-ci")) {
            Object filenames = val;
            while (filenames != Value.NIL && Value.isPair(filenames)) {
                String filename = new String(Value.asString(Value.asPair(filenames).car));
                try {
                    TextStream stream = new TextStream(new java.io.PushbackReader(new java.io.InputStreamReader(new java.io.FileInputStream(new java.io.File(filename)), java.nio.charset.StandardCharsets.UTF_8)), filename);
                    stream.foldCase = true;
                    evaluator.evalFile(stream, filename);
                } catch (java.io.IOException e) {
                    throw new SchemeError(pos, "include-ci: cannot open file ~a: ~a", filename, e.getMessage());
                }
                filenames = Value.asPair(filenames).cdr;
            }
        } else if (what.equals("include-library-declarations")) {
            Object filenames = val;
            while (filenames != Value.NIL && Value.isPair(filenames)) {
                String filename = new String(Value.asString(Value.asPair(filenames).car));
                try {
                    TextStream stream = new TextStream(new java.io.PushbackReader(new java.io.InputStreamReader(new java.io.FileInputStream(new java.io.File(filename)), java.nio.charset.StandardCharsets.UTF_8)), filename);
                    Object form = evaluator.read(stream);
                    while (form != Value.EOF) {
                        processLibraryDeclaration(stream.pos(), Value.asPair(form), module, exports);
                        form = evaluator.read(stream);
                    }
                } catch (java.io.IOException e) {
                    throw new SchemeError(pos, "include-library-declarations: cannot open file ~a: ~a", filename, e.getMessage());
                }
                filenames = Value.asPair(filenames).cdr;
            }
        } else if (what.equals("cond-expand")) {
            // Library-level cond-expand: clauses produce declarations, not expressions
            Primitive featuresPrim = (Primitive) modules.primitives.getPrimitive("%features-list");
            Object featureList = featuresPrim.apply(pos, new Object[0]);

            Object clauses = val;
            while (clauses != Value.NIL && Value.isPair(clauses)) {
                Pair clause = Value.asPair(Value.asPair(clauses).car);
                Object test = clause.car;
                if (featureSatisfied(test, featureList)) {
                    Object body = clause.cdr;
                    while (body != Value.NIL && Value.isPair(body)) {
                        processLibraryDeclaration(pos, Value.asPair(Value.asPair(body).car), module, exports);
                        body = Value.asPair(body).cdr;
                    }
                    break;
                }
                clauses = Value.asPair(clauses).cdr;
            }
        } else if (what.equals("begin")) {
            evaluator.eval(pos, current);
        }
    }

    /**
     * Expand (cond-expand clause ...) at expansion time.
     * Each clause is (feature-requirement expr ...). Evaluates feature requirements
     * and expands the first matching clause as (begin expr ...).
     */
    private Object expandCondExpand(SourcePos pos, Object form) {
        // Get the feature list from the primitive
        Primitive featuresPrim = (Primitive) modules.primitives.getPrimitive("%features-list");
        Object featureList = featuresPrim.apply(pos, new Object[0]);

        // Walk clauses
        Object clauses = formNthCdr(form, 1);
        while (clauses != Value.NIL) {
            if (!Value.isPair(clauses)) break;

            Object clause = Value.asPair(clauses).car;
            if (!Value.isPair(clause)) { clauses = Value.asPair(clauses).cdr; continue; }

            Object req = Value.asPair(clause).car;
            Object body = Value.asPair(clause).cdr;

            if (featureSatisfied(req, featureList))
                return expandBegin(pos, body);

            clauses = Value.asPair(clauses).cdr;
        }

        // No clause matched — return void
        return new Pair(coreFormId("begin"), Value.NIL);
    }

    /**
     * Evaluate a cond-expand feature requirement against the feature list.
     * Supports: identifier, else, (and ...), (or ...), (not ...), (library ...).
     */
    private boolean featureSatisfied(Object req, Object featureList) {
        // Strip SyntaxObject wrappers for inspection
        Object stripped = SyntaxObject.strip(req);

        // Symbol: check if it's 'else or a feature name
        if (Value.isSymbol(stripped)) {
            String name = Value.asSymbol(stripped);
            if (name.equals("else")) return true;
            // Check membership in feature list
            Object cur = featureList;
            while (cur != Value.NIL && Value.isPair(cur)) {
                if (Value.isSymbol(Value.asPair(cur).car)
                    && Value.asSymbol(Value.asPair(cur).car).equals(name))
                    return true;
                cur = Value.asPair(cur).cdr;
            }
            return false;
        }

        // Pair: compound requirement
        if (Value.isPair(stripped)) {
            Object op = Value.asPair(stripped).car;
            String opName = Value.isSymbol(op) ? Value.asSymbol(op) : null;
            Object args = Value.asPair(stripped).cdr;

            if ("and".equals(opName)) {
                while (args != Value.NIL && Value.isPair(args)) {
                    if (!featureSatisfied(Value.asPair(args).car, featureList))
                        return false;
                    args = Value.asPair(args).cdr;
                }
                return true;
            }
            if ("or".equals(opName)) {
                while (args != Value.NIL && Value.isPair(args)) {
                    if (featureSatisfied(Value.asPair(args).car, featureList))
                        return true;
                    args = Value.asPair(args).cdr;
                }
                return false;
            }
            if ("not".equals(opName)) {
                return !featureSatisfied(Value.asPair(args).car, featureList);
            }
            if ("library".equals(opName)) {
                // (library <name>) — check if module can be found
                Object libName = Value.asPair(args).car;
                String moduleName = Modules.asModuleName(SyntaxObject.strip(libName));
                if (modules.getModule(moduleName) != null) return true;
                if (ModulePath.findBuiltinLibraryStream(moduleName, ".sld") != null) return true;
                return ModulePath.findModule(modules, moduleName) != null;
            }
        }

        return false;
    }

    // ---- Quasiquote Expansion ----

    /** Expand a quasiquote form. datum is the content inside (quasiquote ...). */
    private Object expandQuasiquote(SourcePos pos, Object datum) {
        return expandQQ(pos, datum, 0);
    }

    /** Recursive quasiquote expansion with nesting depth tracking. */
    private Object expandQQ(SourcePos pos, Object exp, int nesting) {
        // In sets-of-scopes, only identifiers are wrapped in SyntaxObject.
        // Pairs are not wrapped. We just work with pairs directly.
        Object exposed = exp;
        if (exposed instanceof SyntaxObject && ((SyntaxObject) exposed).isIdentifier()) {
            // A bare identifier in quasiquote context — quote it
            return Pair.list(coreFormId("quote"), SyntaxObject.strip(exposed));
        }

        // Vector: (apply vector <expanded-list>)
        if (Value.isVector(exposed)) {
            Object[] vec = Value.asVector(exposed);
            Object asList = Value.NIL;
            for (int i = vec.length - 1; i >= 0; i--)
                asList = new Pair(vec[i], asList);
            return Pair.list(coreFormId("apply"), coreFormId("vector"),
                expandQQ(pos, asList, nesting));
        }

        // Non-pair: constants are self-quoting, symbols/identifiers get quoted
        if (!Value.isPair(exposed) || exposed == Value.NIL) {
            if (isQQConstant(exposed))
                return SyntaxObject.strip(exposed);
            return Pair.list(coreFormId("quote"), SyntaxObject.strip(exposed));
        }

        Pair p = Value.asPair(exposed);
        String carName = getQQName(p.car);

        // (unquote expr) — length 2
        if ("unquote".equals(carName) && qqListLength(exposed) == 2) {
            Object inner = Value.asPair(p.cdr).car;
            if (nesting == 0)
                return expandForm(pos, inner);
            return combineSkeletons(
                Pair.list(coreFormId("quote"), Value.intern("unquote")),
                expandQQ(pos, p.cdr, nesting - 1),
                SyntaxObject.strip(exposed));
        }

        // (quasiquote expr) — nested quasiquote, length 2
        if ("quasiquote".equals(carName) && qqListLength(exposed) == 2) {
            return combineSkeletons(
                Pair.list(coreFormId("quote"), Value.intern("quasiquote")),
                expandQQ(pos, p.cdr, nesting + 1),
                SyntaxObject.strip(exposed));
        }

        // ((unquote-splicing expr) . rest)
        Object carExposed = p.car;
        if (Value.isPair(carExposed)) {
            String caarName = getQQName(Value.asPair(carExposed).car);
            if ("unquote-splicing".equals(caarName) && qqListLength(carExposed) == 2) {
                Object splicedExpr = Value.asPair(Value.asPair(carExposed).cdr).car;
                if (nesting == 0) {
                    return Pair.list(coreFormId("append"),
                        expandForm(pos, splicedExpr),
                        expandQQ(pos, p.cdr, nesting));
                }
                return combineSkeletons(
                    expandQQ(pos, p.car, nesting - 1),
                    expandQQ(pos, p.cdr, nesting),
                    SyntaxObject.strip(exposed));
            }
        }

        // Regular pair
        return combineSkeletons(
            expandQQ(pos, p.car, nesting),
            expandQQ(pos, p.cdr, nesting),
            SyntaxObject.strip(exposed));
    }

    /** Combine expanded car (left) and cdr (right) into an optimal form. */
    private Object combineSkeletons(Object left, Object right, Object originalExp) {
        boolean leftConst = isQQConstant(left);
        boolean rightConst = isQQConstant(right);

        if (leftConst && rightConst) {
            Object leftVal = isQuoteForm(left) ? Value.asPair(left).second() : left;
            Object rightVal = isQuoteForm(right) ? Value.asPair(right).second() : right;
            return Pair.list(coreFormId("quote"), new Pair(leftVal, rightVal));
        }
        if (rightConst && isQuoteForm(right)
            && Value.asPair(right).second() == Value.NIL) {
            return Pair.list(coreFormId("list"), left);
        }
        String rightCarName = Value.isPair(right) ? getQQName(Value.asPair(right).car) : null;
        if ("list".equals(rightCarName)) {
            java.util.List<Object> parts = new java.util.ArrayList<>();
            parts.add(coreFormId("list"));
            parts.add(left);
            Object cur = Value.asPair(right).cdr;
            while (cur != Value.NIL && Value.isPair(cur)) {
                parts.add(Value.asPair(cur).car);
                cur = Value.asPair(cur).cdr;
            }
            return Pair.list(parts.toArray(new Object[0]));
        }
        return Pair.list(coreFormId("cons"), left, right);
    }

    /** Check if a value is a self-quoting constant or (quote x) form. */
    private static boolean isQQConstant(Object x) {
        if (x == Value.NIL) return true;
        if (Value.isConstant(x)) return true;
        return isQuoteForm(x);
    }

    /** Check if x is (quote datum). */
    private static boolean isQuoteForm(Object x) {
        if (!Value.isPair(x) || x == Value.NIL) return false;
        Object car = Value.asPair(x).car;
        if (Value.isSymbol(car)) return Value.asSymbol(car).equals("quote");
        if (car instanceof SyntaxObject && ((SyntaxObject) car).isIdentifier())
            return ((SyntaxObject) car).symbolName().equals("quote");
        return false;
    }

    /** Get identifier name from a possibly-wrapped object (for quasiquote keywords). */
    private static String getQQName(Object x) {
        if (x instanceof SyntaxObject && ((SyntaxObject) x).isIdentifier())
            return ((SyntaxObject) x).symbolName();
        if (Value.isSymbol(x)) return Value.asSymbol(x);
        return null;
    }

    /** Count elements in a list (for quasiquote). */
    private static int qqListLength(Object x) {
        int n = 0;
        Object cur = x;
        while (true) {
            if (cur == Value.NIL || !Value.isPair(cur)) return n;
            n++;
            cur = Value.asPair(cur).cdr;
        }
    }

    private Object expandApplication(SourcePos pos, Object form) {
        // Expand all sub-expressions
        ArrayList<Object> expanded = new ArrayList<>();
        Object cur = form;
        while (cur != Value.NIL) {
            if (!Value.isPair(cur)) break;
            expanded.add(expandForm(pos, Value.asPair(cur).car));
            cur = Value.asPair(cur).cdr;
        }
        return ((Pair)Pair.list(expanded.toArray())).withPos(pos);
    }

    // ---- Form Navigation Helpers ----
    // In sets-of-scopes, pairs are never wrapped in SyntaxObject,
    // so these helpers are simpler than the old Dybvig versions.

    /** Get the Nth element of a form. */
    private static Object formNth(Object form, int n) {
        Object cur = form;
        for (int i = 0; i < n; i++) {
            if (!Value.isPair(cur)) return Value.NIL;
            cur = Value.asPair(cur).cdr;
        }
        if (!Value.isPair(cur)) return Value.NIL;
        return Value.asPair(cur).car;
    }

    /** Get the cdr from the Nth position of a form. */
    private static Object formNthCdr(Object form, int n) {
        Object cur = form;
        for (int i = 0; i < n; i++) {
            if (!Value.isPair(cur)) return Value.NIL;
            cur = Value.asPair(cur).cdr;
        }
        return cur;
    }

    /** Count elements in a form. */
    private static int formLength(Object form) {
        int n = 0;
        Object cur = form;
        while (Value.isPair(cur)) {
            n++;
            cur = Value.asPair(cur).cdr;
        }
        return n;
    }

    // ---- Helpers ----

    private static boolean isMacroPair(Object obj) {
        return obj instanceof MacroTransformer;
    }

    private static Object extractTransformer(Object macroPair) {
        return ((MacroTransformer) macroPair).transformer;
    }
}
