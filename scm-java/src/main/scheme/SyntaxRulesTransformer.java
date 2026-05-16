package scheme;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Native implementation of R7RS syntax-rules pattern matching and template expansion.
 * Uses the Dybvig mark/substitution system for hygiene and referential transparency.
 *
 * Features supported:
 * - Standard pattern matching with pattern variables and literals
 * - Ellipsis repetition in patterns and templates
 * - Ellipsis escaping: (... template) treats template literally
 * - Custom ellipsis identifiers: (syntax-rules custom-ellipsis (literals) rules...)
 * - Mid-list ellipsis: (a b ... c d) matches with ellipsis in the middle
 * - _ as literal: when _ is in the literals list, it's matched literally
 * - _ as wildcard: when _ is NOT in the literals list, it matches anything
 */
public class SyntaxRulesTransformer {

    private final Object[] literals;       // literal identifier names (interned strings)
    private final Rule[] rules;            // pattern/template pairs
    private final String ellipsis;         // ellipsis symbol (default "...")

    /** Check if a symbol is a local variable (always false -- locals are handled by Compiler). */
    private static boolean isLocalVar(String name, Object useEnv) { return false; }
    private final String defModule;        // definition-site module name
    private final boolean underscoreIsLiteral; // whether _ is in the literals list
    private final Map<String, int[]> localVars; // local vars at definition site: name -> {frame, index}

    public SyntaxRulesTransformer(Object[] literals, Rule[] rules, String ellipsis,
                                  String defModule,
                                  Map<String, int[]> localVars) {
        this.literals = literals;
        this.rules = rules;
        this.defModule = defModule;
        this.localVars = localVars;

        // If the ellipsis is in the literals list, disable ellipsis entirely
        // by using a unique symbol that can never appear in user code
        String effectiveEllipsis = ellipsis != null ? ellipsis : "...";
        for (Object lit : literals) {
            String litName = getIdentName(lit);
            if (litName != null && litName.equals(effectiveEllipsis)) {
                effectiveEllipsis = "\u0001disabled-ellipsis\u0001";
                break;
            }
        }
        this.ellipsis = effectiveEllipsis;

        // Check if _ is in the literals list
        boolean underscoreLit = false;
        for (Object lit : literals) {
            String litName = getIdentName(lit);
            if (litName != null && litName.equals("_")) {
                underscoreLit = true;
                break;
            }
        }
        this.underscoreIsLiteral = underscoreLit;
    }

    /**
     * Transform returning RAW syntax objects (not stripped).
     * Used by the Dybvig expander to preserve marks across macro expansion boundaries.
     */
    public Object transformRaw(Object form, Modules modules) {
        for (int i = 0; i < rules.length; i++) {
            List<Binding> bindings = match(rules[i].pattern, form, modules, Value.NIL);
            if (bindings != null) {
                return expandRaw(rules[i].template, bindings, modules);
            }
        }
        // Debug: describe what we got
        String formDesc = describeStx(form);
        String rulesDesc = "";
        for (int i = 0; i < rules.length; i++) {
            Object pat = rules[i].pattern;
            rulesDesc += "\n  rule " + i + ": " + describeStx(pat);
        }
        throw new SchemeError("syntax-rules: no matching pattern for form " + formDesc + rulesDesc);
    }

    private static String describeStx(Object x) {
        if (x instanceof SyntaxObject && ((SyntaxObject) x).isIdentifier())
            return ((SyntaxObject) x).symbolName();
        if (x == Value.NIL) return "()";
        if (Value.isPair(x)) {
            List<String> parts = new ArrayList<>();
            Object cur = x;
            int limit = 10;
            while (!isNil(cur) && isPair(cur) && limit-- > 0) {
                parts.add(describeStx(car(cur)));
                cur = cdr(cur);
            }
            if (!isNil(cur)) parts.add(". " + describeStx(cur));
            return "(" + String.join(" ", parts) + ")";
        }
        try { return Value.printRep(x); } catch (Exception e) { return x != null ? x.getClass().getName() : "null"; }
    }

    /**
     * Expand template returning syntax objects (no stripping).
     * Template identifiers stay as SyntaxObjects; substituted values stay as-is.
     */
    private Object expandRaw(Object template, List<Binding> bindings, Modules modules) {
        HashSet<String> pvars = new HashSet<>();
        for (Binding b : bindings) pvars.add(b.name);

        // In raw mode (called by the Dybvig Expander), the mark protocol handles
        // hygiene. Template identifiers carry the definition-site wrap. Input values
        // carry the use-site wrap. After the Expander adds the expansion mark:
        // - Input identifiers: mark M twice -> cancels -> original marks
        // - Template identifiers: mark M once -> stays -> different from input
        //
        // No gensym-based hygiene needed -- marks provide the distinction.

        HashMap<String, String> gensymMap = new HashMap<>(); // empty -- no gensyms in raw mode
        Object expanded = expandInner(template, bindings, gensymMap, pvars);
        return expanded;
    }

    // ---- Pattern Matching ----

    /**
     * Match a pattern against a datum. The pattern is from the definition site (plain S-expr).
     * The datum is from the use site (plain S-expr).
     * Returns a list of bindings (pattern-var -> matched value), or null if no match.
     * The first element of the pattern (macro name) should already be stripped by the caller.
     */
    private List<Binding> match(Object pattern, Object datum, Modules modules, Object useEnv) {
        List<Binding> bindings = new ArrayList<>();
        if (matchInner(pattern, datum, bindings, modules, useEnv))
            return bindings;
        return null;
    }

    private boolean matchInner(Object pattern, Object datum, List<Binding> bindings,
                                Modules modules, Object useEnv) {
        // Extract identifier names from pattern and datum (handles SyntaxObject)
        String patName = getIdentName(pattern);
        String datName = getIdentName(datum);

        if (patName != null) {
            // Wildcard: _ matches anything (unless _ is a literal)
            if (patName.equals("_") && !underscoreIsLiteral)
                return true;

            // Ellipsis itself doesn't match anything
            if (patName.equals(ellipsis))
                return true;

            // Literal identifier: check using free-identifier=? semantics (R7RS 4.3.2)
            // A literal matches if both refer to the same binding, or both are
            // unbound and have the same name.
            if (isLiteralIdentifier(pattern, modules.getBindingTable())) {
                if (datName == null) return false;
                if (isLocalVar(datName, useEnv)) return false;
                // If both are SyntaxObjects, compare using free-identifier=?
                if (pattern instanceof SyntaxObject && datum instanceof SyntaxObject)
                    return SyntaxObject.freeIdEq((SyntaxObject) pattern, (SyntaxObject) datum, modules.getBindingTable());
                // If one is SyntaxObject and the other is plain: compare by name
                // (both unbound -> same name = match)
                return patName.equals(datName);
            }

            // Pattern variable: matches anything and binds
            bindings.add(new Binding(patName, datum, false, pattern));
            return true;
        }

        // NIL matches NIL
        if (pattern == Value.NIL)
            return isNil(datum);

        // Non-pair constant: must be equal
        if (!Value.isPair(pattern)) {
            // Scheme strings are char[] -- need content comparison, not reference
            if (Value.isString(pattern) && Value.isString(datum))
                return new String(Value.asString(pattern)).equals(new String(Value.asString(datum)));
            return pattern.equals(datum);
        }

        // Vector pattern
        if (Value.isVector(pattern)) {
            if (!Value.isVector(datum)) return false;
            return matchInner(vectorToList(Value.asVector(pattern)),
                vectorToList(Value.asVector(datum)), bindings, modules, useEnv);
        }

        // Pair pattern (using Stx helpers for SyntaxObject-aware traversal)
        Object pCar = car(pattern);
        Object pCdr = cdr(pattern);

        // Ellipsis escape: ((... template) rest...) -- (... X) means X is treated literally
        if (isPair(pCar)) {
            String carCarName = getIdentName(car(pCar));
            if (carCarName != null && carCarName.equals(ellipsis)) {
                Object innerTemplate = car(cdr(pCar));
                if (!isPair(datum)) return false;
                if (!matchLiteral(innerTemplate, car(datum))) return false;
                return matchInner(pCdr, cdr(datum), bindings, modules, useEnv);
            }
        }

        // Check for ellipsis: (sub-pattern ... rest-pattern...)
        if (isPair(pCdr)) {
            String cdrCarName = getIdentName(car(pCdr));
            if (cdrCarName != null && cdrCarName.equals(ellipsis)) {
                return matchEllipsis(pCar, cdr(pCdr), datum, bindings, modules, useEnv);
            }
        }

        // Regular pair: match car and cdr
        if (!isPair(datum)) return false;
        if (!matchInner(pCar, car(datum), bindings, modules, useEnv)) return false;
        return matchInner(pCdr, cdr(datum), bindings, modules, useEnv);
    }

    /** Match datum literally (for ellipsis escape in patterns). */
    private boolean matchLiteral(Object pattern, Object datum) {
        if (Value.isSymbol(pattern) && Value.isSymbol(datum))
            return Value.asSymbol(pattern).equals(Value.asSymbol(datum));
        if (pattern == Value.NIL) return datum == Value.NIL;
        if (!Value.isPair(pattern) || !Value.isPair(datum)) return pattern.equals(datum);
        Pair pp = Value.asPair(pattern);
        Pair dp = Value.asPair(datum);
        return matchLiteral(pp.car, dp.car) && matchLiteral(pp.cdr, dp.cdr);
    }

    /**
     * Match an ellipsis pattern: (subpat ... rest-pattern...) against datum.
     * The ellipsis can be in the middle of the list (mid-list ellipsis).
     */
    private boolean matchEllipsis(Object subpat, Object restPat, Object datum,
                                   List<Binding> bindings, Modules modules, Object useEnv) {
        List<String> subvars = collectPatternVars(subpat);

        // Count proper list prefix (Pair nodes). Handles both proper and improper lists.
        int len = 0;
        Object cursor = datum;
        while (cursor != Value.NIL && Value.isPair(cursor)) {
            len++;
            cursor = Value.asPair(cursor).cdr;
        }

        // Try all possible split points: n elements for the ellipsis, rest for the suffix
        for (int n = len; n >= 0; n--) {
            List<Object> prefix = listTake(datum, n);
            Object suffix = listDrop(datum, n);

            // Try matching the rest pattern against the suffix
            List<Binding> restBindings = new ArrayList<>();
            if (matchInner(restPat, suffix, restBindings, modules, useEnv)) {
                // Try matching each prefix element against subpat
                List<Binding> ellBindings = matchEach(subpat, prefix, subvars, modules, useEnv);
                if (ellBindings != null) {
                    bindings.addAll(ellBindings);
                    bindings.addAll(restBindings);
                    return true;
                }
            }
        }
        return false;
    }

    /** Match subpat against each element in the list, collecting bindings as lists. */
    private List<Binding> matchEach(Object subpat, List<Object> elems,
                                    List<String> subvars, Modules modules, Object useEnv) {
        // Initialize accumulator: one list per pattern variable
        Map<String, List<Object>> acc = new HashMap<>();
        Map<String, Object> identifiers = new HashMap<>();
        for (String v : subvars) {
            acc.put(v, new ArrayList<>());
            identifiers.put(v, null);
        }

        for (Object elem : elems) {
            List<Binding> elemBindings = new ArrayList<>();
            if (!matchInner(subpat, elem, elemBindings, modules, useEnv))
                return null;
            for (Binding b : elemBindings) {
                if (acc.containsKey(b.name)) {
                    // For nested ellipsis: add the list of values, not the value itself
                    if (b.isEllipsis)
                        acc.get(b.name).add(b.values);
                    else
                        acc.get(b.name).add(b.value);
                    if (b.identifier != null)
                        identifiers.put(b.name, b.identifier);
                }
            }
        }

        // Convert to list bindings
        List<Binding> result = new ArrayList<>();
        for (String v : subvars) {
            result.add(new Binding(v, acc.get(v), true, identifiers.get(v)));
        }
        return result;
    }

    @SuppressWarnings("unchecked")
    private Object expandInner(Object template, List<Binding> bindings,
                               Map<String, String> gensymMap, Set<String> pvars) {
        // SyntaxObject identifier
        if (template instanceof SyntaxObject && ((SyntaxObject) template).isIdentifier()) {
            SyntaxObject stx = (SyntaxObject) template;
            String name = stx.symbolName();
            // Use identity-based matching (BoundIdEq) when bindings have
            // SyntaxObject identifiers from pattern matching. This correctly
            // handles macro-generating-macros where template identifiers from
            // an outer expansion have different marks than pattern variables
            // from an inner syntax-rules.
            Binding binding = findBindingByIdentity(template, name, bindings);
            if (binding != null) {
                if (binding.isEllipsis)
                    throw new SchemeError(
                        "syntax-rules: ellipsis pattern variable ~a used outside ellipsis context", name);
                return binding.value;
            }
            // Keep as SyntaxObject
            return template;
        }

        // In sets-of-scopes model, SyntaxObjects only wrap identifiers.
        // A non-identifier SyntaxObject should not occur here; handle gracefully.
        if (template instanceof SyntaxObject)
            template = ((SyntaxObject) template).datum;

        // Plain symbol might be a pattern var
        if (Value.isSymbol(template)) {
            String name = Value.asSymbol(template);
            Binding binding = findBinding(name, bindings);
            if (binding != null) {
                if (binding.isEllipsis)
                    throw new SchemeError(
                        "syntax-rules: ellipsis pattern variable ~a used outside ellipsis context", name);
                return binding.value;
            }
            // Plain symbol not a pattern var -- return as-is (will pass through StripExpanded)
            return template;
        }

        // Not a pair -- return as-is
        if (!Value.isPair(template)) return template;
        if (template == Value.NIL) return Value.NIL;

        Pair tp = Value.asPair(template);

        // In sets-of-scopes, cdr should never be a non-identifier SyntaxObject
        Object cdrExposed = tp.cdr;

        // Ellipsis escape: (... template) -- emit template literally, no ellipsis processing
        if (isEllipsisObj(tp.car)
            && Value.isPair(cdrExposed) && Value.asPair(cdrExposed).cdr == Value.NIL) {
            // (... X) -> X with no ellipsis processing, but still expand identifiers
            return expandNoEllipsis(Value.asPair(cdrExposed).car, bindings, gensymMap, pvars);
        }

        // Check for ellipsis: (sub-template ... rest...)
        if (Value.isPair(cdrExposed) && isEllipsisObj(Value.asPair(cdrExposed).car)) {
            Object subTemplate = tp.car;
            Object restTemplate = Value.asPair(cdrExposed).cdr;

            // Find ellipsis pattern variables in the sub-template
            List<Binding> ellPvars = findEllipsisPvars(subTemplate, bindings);
            if (ellPvars.isEmpty())
                throw new SchemeError(
                    "syntax-rules: no ellipsis variables in ellipsis template position");

            // Determine the iteration count from the first ellipsis pattern variable
            int n = ellPvars.get(0).values.size();

            // Expand for each iteration
            List<Object> expanded = new ArrayList<>();
            for (int i = 0; i < n; i++) {
                // Create iteration bindings: replace list bindings with individual values
                List<Binding> iterBindings = new ArrayList<>(bindings.size());
                for (Binding b : bindings) {
                    if (b.isEllipsis && containsName(ellPvars, b.name)) {
                        Object val = i < b.values.size() ? b.values.get(i) : Value.F;
                        if (val instanceof List)
                            iterBindings.add(new Binding(b.name, (List<Object>) val, true, b.identifier));
                        else
                            iterBindings.add(new Binding(b.name, val, false, b.identifier));
                    } else {
                        iterBindings.add(b);
                    }
                }
                expanded.add(expandInner(subTemplate, iterBindings, gensymMap, pvars));
            }

            // Expand the rest of the template
            Object restExpanded = expandInner(restTemplate, bindings, gensymMap, pvars);

            // Build the result list: expanded elements + rest
            Object result = restExpanded;
            for (int i = expanded.size() - 1; i >= 0; i--)
                result = new Pair(expanded.get(i), result);
            return result;
        }

        // Vector in template
        if (Value.isVector(template)) {
            Object[] vec = Value.asVector(template);
            Object expandedList = expandInner(vectorToList(vec), bindings, gensymMap, pvars);
            return listToVector(expandedList);
        }

        // Regular pair: expand car and cdr
        Object car = expandInner(tp.car, bindings, gensymMap, pvars);
        Object cdr = expandInner(tp.cdr, bindings, gensymMap, pvars);
        // Always create a fresh Pair without source position so that
        // definition-site positions from parsed templates do not leak
        // into expanded output (the expander attaches use-site positions).
        if (car == tp.car && cdr == tp.cdr && tp.pos == null) return template;
        return new Pair(car, cdr);
    }

    /** Helper to check if an element is the ellipsis symbol (plain or wrapped). */
    private boolean isEllipsisObj(Object obj) {
        if (Value.isSymbol(obj)) return Value.asSymbol(obj).equals(ellipsis);
        if (obj instanceof SyntaxObject && ((SyntaxObject) obj).isIdentifier())
            return ((SyntaxObject) obj).symbolName().equals(ellipsis);
        return false;
    }

    /**
     * Expand a template with no ellipsis processing (for ellipsis escape).
     * Free identifiers are still renamed.
     */
    private Object expandNoEllipsis(Object template, List<Binding> bindings,
                                    Map<String, String> gensymMap, Set<String> pvars) {
        // SyntaxObject identifier
        if (template instanceof SyntaxObject && ((SyntaxObject) template).isIdentifier()) {
            SyntaxObject stx = (SyntaxObject) template;
            String name = stx.symbolName();
            Binding binding = findBindingByIdentity(template, name, bindings);
            if (binding != null && !binding.isEllipsis)
                return binding.value;
            return template;
        }
        if (template instanceof SyntaxObject)
            template = ((SyntaxObject) template).datum;
        // Plain symbol: pass through
        if (Value.isSymbol(template))
            return template;
        if (!Value.isPair(template) || template == Value.NIL) return template;
        Pair tp = Value.asPair(template);
        Object car = expandNoEllipsis(tp.car, bindings, gensymMap, pvars);
        Object cdr = expandNoEllipsis(tp.cdr, bindings, gensymMap, pvars);
        if (car == tp.car && cdr == tp.cdr && tp.pos == null) return template;
        return new Pair(car, cdr);
    }

    /** Extract identifier name from a plain symbol or SyntaxObject identifier. */
    private static String getIdentName(Object obj) {
        if (obj instanceof SyntaxObject && ((SyntaxObject) obj).isIdentifier())
            return ((SyntaxObject) obj).symbolName();
        if (Value.isSymbol(obj)) return Value.asSymbol(obj);
        return null;
    }

    // ---- List Traversal Helpers ----
    // These helpers transparently handle SyntaxObject wrappers around pairs,
    // enabling pattern matching and template expansion to work with syntax objects.

    /** Is this a pair? (SyntaxObjects only wrap identifiers, never pairs.) */
    private static boolean isPair(Object x) {
        return Value.isPair(x);
    }

    /** Is this NIL? */
    private static boolean isNil(Object x) {
        return x == Value.NIL;
    }

    /** Get the car of a pair. */
    private static Object car(Object x) {
        return Value.asPair(x).car;
    }

    /** Get the cdr of a pair. */
    private static Object cdr(Object x) {
        return Value.asPair(x).cdr;
    }

    /** Count elements in a list. */
    private static Integer listLength(Object x) {
        int n = 0;
        while (true) {
            if (x == Value.NIL) return n;
            if (!Value.isPair(x)) return null;
            n++;
            x = Value.asPair(x).cdr;
        }
    }

    /** Take first n elements from a list. */
    private static List<Object> listTake(Object ls, int n) {
        List<Object> result = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            if (!Value.isPair(ls) || ls == Value.NIL) break;
            result.add(Value.asPair(ls).car);
            ls = Value.asPair(ls).cdr;
        }
        return result;
    }

    /** Drop first n elements from a list. */
    private static Object listDrop(Object ls, int n) {
        for (int i = 0; i < n; i++) {
            if (!Value.isPair(ls) || ls == Value.NIL) break;
            ls = Value.asPair(ls).cdr;
        }
        return ls;
    }

    /**
     * Check if a pattern element is a literal using bound-identifier=? semantics.
     * Per the sets-of-scopes algorithm, two identifiers with the same name but
     * different scopes are distinct — a pattern identifier is only a literal if it
     * has the same name AND same scope set as an entry in the literals list.
     */
    private boolean isLiteralIdentifier(Object patternElem, BindingTable bindingTable) {
        for (Object lit : literals) {
            // Both SyntaxObjects: use BoundIdEq (same name + same scope set)
            if (patternElem instanceof SyntaxObject && lit instanceof SyntaxObject) {
                SyntaxObject pStx = (SyntaxObject) patternElem;
                SyntaxObject lStx = (SyntaxObject) lit;
                if (pStx.isIdentifier() && lStx.isIdentifier() && SyntaxObject.boundIdEq(pStx, lStx))
                    return true;
            }
            // Both must be SyntaxObjects -- plain symbols indicate a wrapping bug upstream
            else {
                String pName = getIdentName(patternElem);
                String lName = getIdentName(lit);
                if (pName != null || lName != null)
                    throw new SchemeError("internal: isLiteralIdentifier received non-SyntaxObject identifier: pattern=" + patternElem + ", literal=" + lit);
            }
        }
        return false;
    }

    /** Collect pattern variable names from a pattern. */
    private List<String> collectPatternVars(Object pattern) {
        List<String> vars = new ArrayList<>();
        collectPatternVarsInner(pattern, vars);
        return vars;
    }

    private void collectPatternVarsInner(Object pattern, List<String> vars) {
        if (isNil(pattern)) return;
        // Handle SyntaxObject and plain symbol identifiers
        String name = getIdentName(pattern);
        if (name != null) {
            if (name.equals("_") && !underscoreIsLiteral) return;
            if (name.equals(ellipsis)) return;
            if (isLiteralIdentifier(pattern, null)) return;
            if (!vars.contains(name)) vars.add(name);
            return;
        }
        if (!isPair(pattern)) return;
        Object pCar = car(pattern);
        Object pCdr = cdr(pattern);
        // Skip ellipsis following a sub-pattern
        if (isPair(pCdr)) {
            String cdrCarName = getIdentName(car(pCdr));
            if (cdrCarName != null && cdrCarName.equals(ellipsis)) {
                collectPatternVarsInner(pCar, vars);
                collectPatternVarsInner(cdr(pCdr), vars);
                return;
            }
        }
        collectPatternVarsInner(pCar, vars);
        collectPatternVarsInner(pCdr, vars);
    }

    private Binding findBinding(String name, List<Binding> bindings) {
        for (int i = 0; i < bindings.size(); i++)
            if (bindings.get(i).name.equals(name)) return bindings.get(i);
        return null;
    }

    /**
     * Find a binding matching both name AND identity (marks).
     * When both the template identifier and the binding's pattern identifier are SyntaxObjects,
     * use BoundIdEq to check they have the same marks (same expansion context).
     */
    private Binding findBindingByIdentity(Object templateIdent, String name, List<Binding> bindings) {
        for (int i = 0; i < bindings.size(); i++) {
            if (!bindings.get(i).name.equals(name)) continue;
            // If both are SyntaxObjects, use BoundIdEq for mark comparison
            if (templateIdent instanceof SyntaxObject && bindings.get(i).identifier instanceof SyntaxObject) {
                if (SyntaxObject.boundIdEq((SyntaxObject) templateIdent, (SyntaxObject) bindings.get(i).identifier))
                    return bindings.get(i);
                // Same name but different marks -- not the same binding
                continue;
            }
            // Both must be SyntaxObjects -- plain symbol bindings indicate a wrapping bug upstream
            if (!(bindings.get(i).identifier instanceof SyntaxObject))
                throw new SchemeError("internal: findBindingByIdentity found plain symbol binding for: " + name);
            // Template is plain but binding has SyntaxObject -- no match
        }
        return null;
    }

    private List<Binding> findEllipsisPvars(Object template, List<Binding> bindings) {
        HashSet<String> names = new HashSet<>();
        collectTemplateVarRefs(template, names);
        List<Binding> result = new ArrayList<>();
        for (Binding b : bindings) {
            if (b.isEllipsis && names.contains(b.name))
                result.add(b);
        }
        return result;
    }

    private void collectTemplateVarRefs(Object template, HashSet<String> names) {
        if (template instanceof SyntaxObject && ((SyntaxObject) template).isIdentifier())
            { names.add(((SyntaxObject) template).symbolName()); return; }
        if (Value.isSymbol(template)) { names.add(Value.asSymbol(template)); return; }
        if (!Value.isPair(template) || template == Value.NIL) return;
        Pair tp = Value.asPair(template);
        collectTemplateVarRefs(tp.car, names);
        collectTemplateVarRefs(tp.cdr, names);
    }

    private static Object vectorToList(Object[] vec) {
        Object result = Value.NIL;
        for (int i = vec.length - 1; i >= 0; i--)
            result = new Pair(vec[i], result);
        return result;
    }

    private static Object[] listToVector(Object list) {
        List<Object> elems = new ArrayList<>();
        while (list != Value.NIL && Value.isPair(list)) {
            elems.add(Value.asPair(list).car);
            list = Value.asPair(list).cdr;
        }
        return elems.toArray();
    }

    private static boolean containsName(List<Binding> bindings, String name) {
        for (Binding b : bindings) {
            if (b.name.equals(name)) return true;
        }
        return false;
    }

    // ---- Parsing ----

    /**
     * Parse a syntax-rules form and create a SyntaxRulesTransformer.
     * Form: (syntax-rules (literal ...) (pattern template) ...)
     * Or:   (syntax-rules ellipsis (literal ...) (pattern template) ...)
     * The first element (syntax-rules keyword) should already be stripped.
     */
    public static SyntaxRulesTransformer parse(Object args, String defModule, Modules modules,
                                               Map<String, int[]> localVars) {
        // In sets-of-scopes, pairs are never wrapped in SyntaxObject
        if (args == Value.NIL || !Value.isPair(args))
            throw new SchemeError("syntax-rules: invalid form");

        Pair argsPair = Value.asPair(args);
        String customEllipsis = null;
        Object rest = args;

        // Check for custom ellipsis: (syntax-rules <identifier> (<literals>) <rules>...)
        String firstArgName = getIdentName(argsPair.car);
        if (firstArgName != null && !firstArgName.equals("_")) {
            // First arg is an identifier (not a list) -- it's a custom ellipsis
            String potentialEllipsis = firstArgName;
            // Make sure the next arg is a list (the literals)
            Object nextArg = argsPair.cdr;
            if (Value.isPair(nextArg)) {
                Object nextCar = Value.asPair(nextArg).car;
                if (Value.isPair(nextCar) || nextCar == Value.NIL) {
                    customEllipsis = potentialEllipsis;
                    rest = nextArg;
                }
            }
        }

        // Parse literals list
        Pair restPair = Value.asPair(rest);
        List<Object> literals = new ArrayList<>();
        Object litList = restPair.car;
        while (litList != Value.NIL && Value.isPair(litList)) {
            literals.add(Value.asPair(litList).car); // Store as-is (may be SyntaxObject)
            litList = Value.asPair(litList).cdr;
        }

        // Parse rules
        List<Rule> rules = new ArrayList<>();
        Object ruleList = restPair.cdr;
        while (ruleList != Value.NIL && Value.isPair(ruleList)) {
            Object ruleObj = Value.asPair(ruleList).car;
            if (!Value.isPair(ruleObj))
                throw new SchemeError("syntax-rules: rule must be a pair, got " + (ruleObj != null ? ruleObj.getClass().getSimpleName() : "null"));
            Pair rule = Value.asPair(ruleObj);
            // rule = (pattern template)
            Object pattern = rule.car;
            Object ruleCdr = rule.cdr;
            Object template = Value.isPair(ruleCdr) ? Value.asPair(ruleCdr).car : Value.NIL;
            // Skip the first element of the pattern (macro name)
            if (Value.isPair(pattern))
                pattern = Value.asPair(pattern).cdr;
            rules.add(new Rule(pattern, template)); // Store as-is (may contain SyntaxObjects)
            ruleList = Value.asPair(ruleList).cdr;
        }

        return new SyntaxRulesTransformer(
            literals.toArray(),
            rules.toArray(new Rule[0]),
            customEllipsis != null ? customEllipsis : "...",
            defModule,
            localVars);
    }

    /** A pattern/template pair in a syntax-rules form. */
    public static class Rule {
        public final Object pattern;   // Pattern (cdr of the original, skipping macro name)
        public final Object template;  // Template

        public Rule(Object pattern, Object template) {
            this.pattern = pattern;
            this.template = template;
        }
    }

    /** A binding from pattern matching. */
    public static class Binding {
        public final String name;
        public final Object identifier;   // Original identifier (SyntaxObject or plain symbol) from pattern
        public final Object value;        // For non-ellipsis: the matched datum
        public final List<Object> values; // For ellipsis: list of matched datums
        public final boolean isEllipsis;

        public Binding(String name, Object value) {
            this(name, value, false, null);
        }

        @SuppressWarnings("unchecked")
        public Binding(String name, Object value, boolean isEllipsis) {
            this(name, value, isEllipsis, null);
        }

        @SuppressWarnings("unchecked")
        public Binding(String name, Object value, boolean isEllipsis, Object identifier) {
            this.name = name;
            this.identifier = identifier;
            if (isEllipsis) {
                this.values = (List<Object>) value;
                this.value = null;
                this.isEllipsis = true;
            } else {
                this.value = value;
                this.values = null;
                this.isEllipsis = false;
            }
        }
    }
}
