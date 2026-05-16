using System.Collections.Generic;

namespace scheme;

/// <summary>
/// Native implementation of R7RS syntax-rules pattern matching and template expansion.
/// Uses the Dybvig mark/substitution system for hygiene and referential transparency.
///
/// Features supported:
/// - Standard pattern matching with pattern variables and literals
/// - Ellipsis repetition in patterns and templates
/// - Ellipsis escaping: (... template) treats template literally
/// - Custom ellipsis identifiers: (syntax-rules custom-ellipsis (literals) rules...)
/// - Mid-list ellipsis: (a b ... c d) matches with ellipsis in the middle
/// - _ as literal: when _ is in the literals list, it's matched literally
/// - _ as wildcard: when _ is NOT in the literals list, it matches anything
/// </summary>
public class SyntaxRulesTransformer
{
    private readonly object[] literals;   // literal identifier names (interned strings)
    private readonly Rule[] rules;        // pattern/template pairs
    private readonly string ellipsis;     // ellipsis symbol (default "...")

    /// <summary>Check if a symbol is a local variable (always false — locals are handled by Compiler).</summary>
    private static bool IsLocalVar(string name, object useEnv) => false;
    private readonly string defModule;    // definition-site module name
    private readonly bool underscoreIsLiteral; // whether _ is in the literals list
    private readonly Dictionary<string, (int frame, int index)>? localVars; // local vars at definition site

    public SyntaxRulesTransformer(object[] literals, Rule[] rules, string ellipsis,
                                  string defModule,
                                  Dictionary<string, (int frame, int index)>? localVars = null)
    {
        this.literals = literals;
        this.rules = rules;
        this.defModule = defModule;
        this.localVars = localVars;

        // If the ellipsis is in the literals list, disable ellipsis entirely
        // by using a unique symbol that can never appear in user code
        string effectiveEllipsis = ellipsis ?? "...";
        foreach (var lit in literals)
        {
            string? litName = GetIdentName(lit);
            if (litName != null && litName == effectiveEllipsis)
            {
                effectiveEllipsis = "\x01disabled-ellipsis\x01";
                break;
            }
        }
        this.ellipsis = effectiveEllipsis;

        // Check if _ is in the literals list
        underscoreIsLiteral = false;
        foreach (var lit in literals)
        {
            string? litName = GetIdentName(lit);
            if (litName != null && litName == "_")
            {
                underscoreIsLiteral = true;
                break;
            }
        }
    }

    /// <summary>
    /// Transform returning RAW syntax objects (not stripped).
    /// Used by the Dybvig expander to preserve marks across macro expansion boundaries.
    /// </summary>
    public object TransformRaw(object form, Modules modules)
    {
        for (int i = 0; i < rules.Length; i++)
        {
            var bindings = Match(rules[i].Pattern, form, modules, Value.NIL);
            if (bindings != null)
            {
                return ExpandRaw(rules[i].Template, bindings, modules);
            }
        }
        // Debug: describe what we got
        string formDesc = DescribeStx(form);
        string rulesDesc = "";
        for (int i = 0; i < rules.Length; i++)
            rulesDesc += "\n  rule " + i + ": " + DescribeStx(rules[i].Pattern);
        throw new SchemeError("syntax-rules: no matching pattern for form " + formDesc + rulesDesc);
    }

    private static string DescribeStx(object x)
    {
        if (x is SyntaxObject stx && stx.IsIdentifier)
            return stx.SymbolName;
        if (x == Value.NIL) return "()";
        if (Value.IsPair(x))
        {
            var parts = new List<string>();
            object cur = x;
            int limit = 10;
            while (!IsNil(cur) && IsPair(cur) && limit-- > 0)
            {
                parts.Add(DescribeStx(Car(cur)));
                cur = Cdr(cur);
            }
            if (!IsNil(cur)) parts.Add(". " + DescribeStx(cur));
            return "(" + string.Join(" ", parts) + ")";
        }
        try { return Value.PrintRep(x); } catch { return x?.GetType().Name ?? "null"; }
    }

    /// <summary>
    /// Expand template returning syntax objects (no stripping).
    /// Template identifiers stay as SyntaxObjects; substituted values stay as plain S-expressions.
    /// </summary>
    private object ExpandRaw(object template, List<Binding> bindings, Modules modules)
    {
        var pvars = new HashSet<string>();
        foreach (var b in bindings) pvars.Add(b.Name);

        // In raw mode (called by the Dybvig Expander), the mark protocol handles
        // hygiene. Template identifiers carry the definition-site wrap. Input values
        // carry the use-site wrap. After the Expander adds the expansion mark:
        // - Input identifiers: mark M twice → cancels → original marks
        // - Template identifiers: mark M once → stays → different from input
        //
        // No gensym-based hygiene needed — marks provide the distinction.

        var gensymMap = new Dictionary<string, string>(); // empty — no gensyms in raw mode
        object expanded = ExpandInner(template, bindings, gensymMap, pvars);
        return expanded;
    }

    // ---- Pattern Matching ----

    /// <summary>
    /// Match a pattern against a datum. The pattern is from the definition site (plain S-expr).
    /// The datum is from the use site (plain S-expr).
    /// Returns a list of bindings (pattern-var → matched value), or null if no match.
    /// The first element of the pattern (macro name) should already be stripped by the caller.
    /// </summary>
    private List<Binding>? Match(object pattern, object datum, Modules modules, object useEnv)
    {
        var bindings = new List<Binding>();
        if (MatchInner(pattern, datum, bindings, modules, useEnv))
            return bindings;
        return null;
    }

    private bool MatchInner(object pattern, object datum, List<Binding> bindings,
                            Modules modules, object useEnv)
    {
        // Extract identifier names from pattern and datum (handles SyntaxObject)
        string? patName = GetIdentName(pattern);
        string? datName = GetIdentName(datum);

        if (patName != null)
        {
            // Wildcard: _ matches anything (unless _ is a literal)
            if (patName == "_" && !underscoreIsLiteral)
                return true;

            // Ellipsis itself doesn't match anything
            if (patName == ellipsis)
                return true;

            // Literal identifier: check using free-identifier=? semantics (R7RS 4.3.2)
            // A literal matches if both refer to the same binding, or both are
            // unbound and have the same name.
            if (IsLiteralIdentifier(pattern, modules.BindingTable))
            {
                if (datName == null) return false;
                if (IsLocalVar(datName, useEnv)) return false;
                // If both are SyntaxObjects, compare using free-identifier=?
                if (pattern is SyntaxObject pStx2 && datum is SyntaxObject dStx2)
                    return SyntaxObject.FreeIdEq(pStx2, dStx2, modules.BindingTable);
                // If one is SyntaxObject and the other is plain: compare by name
                // (both unbound → same name = match)
                return patName == datName;
            }

            // Pattern variable: matches anything and binds
            bindings.Add(new Binding(patName, datum, false, pattern));
            return true;
        }

        // NIL matches NIL
        if (pattern == Value.NIL)
            return IsNil(datum);

        // Non-pair constant: must be equal
        if (!Value.IsPair(pattern))
        {
            // Scheme strings are char[] — need content comparison, not reference
            if (Value.IsString(pattern) && Value.IsString(datum))
                return new string(Value.AsString(pattern)) == new string(Value.AsString(datum));
            return pattern.Equals(datum);
        }

        // Vector pattern
        if (Value.IsVector(pattern))
        {
            if (!Value.IsVector(datum)) return false;
            return MatchInner(VectorToList(Value.AsVector(pattern)),
                VectorToList(Value.AsVector(datum)), bindings, modules, useEnv);
        }

        // Pair pattern (using Stx helpers for SyntaxObject-aware traversal)
        object pCar = Car(pattern);
        object pCdr = Cdr(pattern);

        // Ellipsis escape: ((... template) rest...) — (... X) means X is treated literally
        if (IsPair(pCar))
        {
            string? carCarName = GetIdentName(Car(pCar));
            if (carCarName == ellipsis)
            {
                object innerTemplate = Car(Cdr(pCar));
                if (!IsPair(datum)) return false;
                if (!MatchLiteral(innerTemplate, Car(datum))) return false;
                return MatchInner(pCdr, Cdr(datum), bindings, modules, useEnv);
            }
        }

        // Check for ellipsis: (sub-pattern ... rest-pattern...)
        if (IsPair(pCdr))
        {
            string? cdrCarName = GetIdentName(Car(pCdr));
            if (cdrCarName == ellipsis)
            {
                return MatchEllipsis(pCar, Cdr(pCdr), datum, bindings, modules, useEnv);
            }
        }

        // Regular pair: match car and cdr
        if (!IsPair(datum)) return false;
        if (!MatchInner(pCar, Car(datum), bindings, modules, useEnv)) return false;
        return MatchInner(pCdr, Cdr(datum), bindings, modules, useEnv);
    }

    /// <summary>Match datum literally (for ellipsis escape in patterns).</summary>
    private bool MatchLiteral(object pattern, object datum)
    {
        if (Value.IsSymbol(pattern) && Value.IsSymbol(datum))
            return Value.AsSymbol(pattern) == Value.AsSymbol(datum);
        if (pattern == Value.NIL) return datum == Value.NIL;
        if (!Value.IsPair(pattern) || !Value.IsPair(datum)) return pattern.Equals(datum);
        Pair pp = Value.AsPair(pattern);
        Pair dp = Value.AsPair(datum);
        return MatchLiteral(pp.car, dp.car) && MatchLiteral(pp.cdr, dp.cdr);
    }

    /// <summary>
    /// Match an ellipsis pattern: (subpat ... rest-pattern...) against datum.
    /// The ellipsis can be in the middle of the list (mid-list ellipsis).
    /// </summary>
    private bool MatchEllipsis(object subpat, object restPat, object datum,
                               List<Binding> bindings, Modules modules, object useEnv)
    {
        var subvars = CollectPatternVars(subpat);

        // Count proper list prefix (Pair nodes). Handles both proper and improper lists.
        int len = 0;
        object cursor = datum;
        while (cursor != Value.NIL && Value.IsPair(cursor))
        {
            len++;
            cursor = Value.AsPair(cursor).cdr;
        }

        // Try all possible split points: n elements for the ellipsis, rest for the suffix
        for (int n = len; n >= 0; n--)
        {
            var prefix = ListTake(datum, n);
            var suffix = ListDrop(datum, n);

            // Try matching the rest pattern against the suffix
            var restBindings = new List<Binding>();
            if (MatchInner(restPat, suffix, restBindings, modules, useEnv))
            {
                // Try matching each prefix element against subpat
                var ellBindings = MatchEach(subpat, prefix, subvars, modules, useEnv);
                if (ellBindings != null)
                {
                    bindings.AddRange(ellBindings);
                    bindings.AddRange(restBindings);
                    return true;
                }
            }
        }
        return false;
    }

    /// <summary>Match subpat against each element in the list, collecting bindings as lists.</summary>
    private List<Binding>? MatchEach(object subpat, List<object> elems,
                                    List<string> subvars, Modules modules, object useEnv)
    {
        // Initialize accumulator: one list per pattern variable
        var acc = new Dictionary<string, List<object>>();
        var identifiers = new Dictionary<string, object?>();
        foreach (var v in subvars)
        {
            acc[v] = new List<object>();
            identifiers[v] = null;
        }

        foreach (var elem in elems)
        {
            var elemBindings = new List<Binding>();
            if (!MatchInner(subpat, elem, elemBindings, modules, useEnv))
                return null;
            foreach (var b in elemBindings)
            {
                if (acc.ContainsKey(b.Name))
                {
                    // For nested ellipsis: add the list of values, not the value itself
                    if (b.IsEllipsis)
                        acc[b.Name].Add(b.Values!);
                    else
                        acc[b.Name].Add(b.Value!);
                    if (b.Identifier != null)
                        identifiers[b.Name] = b.Identifier;
                }
            }
        }

        // Convert to list bindings
        var result = new List<Binding>();
        foreach (var v in subvars)
        {
            result.Add(new Binding(v, acc[v], true, identifiers[v]));
        }
        return result;
    }

    private object ExpandInner(object template, List<Binding> bindings,
                               Dictionary<string, string> gensymMap, HashSet<string> pvars)
    {
        // SyntaxObject identifier
        if (template is SyntaxObject stx && stx.IsIdentifier)
        {
            string name = stx.SymbolName;
            // Use identity-based matching (BoundIdEq) when bindings have
            // SyntaxObject identifiers from pattern matching. This correctly
            // handles macro-generating-macros where template identifiers from
            // an outer expansion have different marks than pattern variables
            // from an inner syntax-rules.
            var binding = FindBindingByIdentity(template, name, bindings);
            if (binding != null)
            {
                if (binding.IsEllipsis)
                    throw new SchemeError(
                        "syntax-rules: ellipsis pattern variable ~a used outside ellipsis context", name);
                return binding.Value!;
            }
            // Keep as SyntaxObject
            return template;
        }

        // In sets-of-scopes model, SyntaxObjects only wrap identifiers.
        // A non-identifier SyntaxObject should not occur here; handle gracefully.
        if (template is SyntaxObject so)
            template = so.Datum;

        // Plain symbol might be a pattern var
        if (Value.IsSymbol(template))
        {
            string name = Value.AsSymbol(template);
            var binding = FindBinding(name, bindings);
            if (binding != null)
            {
                if (binding.IsEllipsis)
                    throw new SchemeError(
                        "syntax-rules: ellipsis pattern variable ~a used outside ellipsis context", name);
                return binding.Value!;
            }
            // Plain symbol not a pattern var — return as-is (will pass through StripExpanded)
            return template;
        }

        // Not a pair — return as-is
        if (!Value.IsPair(template)) return template;
        if (template == Value.NIL) return Value.NIL;

        Pair tp = Value.AsPair(template);

        // Helper to check if an element is the ellipsis symbol (plain or wrapped)
        bool IsEllipsisObj(object obj)
        {
            if (Value.IsSymbol(obj)) return Value.AsSymbol(obj) == ellipsis;
            if (obj is SyntaxObject s && s.IsIdentifier) return s.SymbolName == ellipsis;
            return false;
        }

        // In sets-of-scopes, pairs are never wrapped in SyntaxObject, so cdr is always plain
        object cdrExposed = tp.cdr;

        // Ellipsis escape: (... template) — emit template literally, no ellipsis processing
        if (IsEllipsisObj(tp.car)
            && Value.IsPair(cdrExposed) && Value.AsPair(cdrExposed).cdr == Value.NIL)
        {
            // (... X) → X with no ellipsis processing, but still expand identifiers
            return ExpandNoEllipsis(Value.AsPair(cdrExposed).car, bindings, gensymMap, pvars);
        }

        // Check for ellipsis: (sub-template ... rest...)
        if (Value.IsPair(cdrExposed) && IsEllipsisObj(Value.AsPair(cdrExposed).car))
        {
            object subTemplate = tp.car;
            object restTemplate = Value.AsPair(cdrExposed).cdr;

            // Find ellipsis pattern variables in the sub-template
            var ellPvars = FindEllipsisPvars(subTemplate, bindings);
            if (ellPvars.Count == 0)
                throw new SchemeError(
                    "syntax-rules: no ellipsis variables in ellipsis template position");

            // Determine the iteration count from the first ellipsis pattern variable
            int n = ellPvars[0].Values!.Count;

            // Expand for each iteration
            var expanded = new List<object>();
            for (int i = 0; i < n; i++)
            {
                // Create iteration bindings: replace list bindings with individual values
                var iterBindings = new List<Binding>(bindings.Count);
                foreach (var b in bindings)
                {
                    if (b.IsEllipsis && ellPvars.Exists(e => e.Name == b.Name))
                    {
                        object val = i < b.Values!.Count ? b.Values[i] : Value.F;
                        if (val is List<object> nestedList)
                            iterBindings.Add(new Binding(b.Name, nestedList, true, b.Identifier));
                        else
                            iterBindings.Add(new Binding(b.Name, val, false, b.Identifier));
                    }
                    else
                    {
                        iterBindings.Add(b);
                    }
                }
                expanded.Add(ExpandInner(subTemplate, iterBindings, gensymMap, pvars));
            }

            // Expand the rest of the template
            object restExpanded = ExpandInner(restTemplate, bindings, gensymMap, pvars);

            // Build the result list: expanded elements + rest
            object result = restExpanded;
            for (int i = expanded.Count - 1; i >= 0; i--)
                result = new Pair(expanded[i], result);
            return result;
        }

        // Vector in template
        if (Value.IsVector(template))
        {
            var vec = Value.AsVector(template);
            var expandedList = ExpandInner(VectorToList(vec), bindings, gensymMap, pvars);
            return ListToVector(expandedList);
        }

        // Regular pair: expand car and cdr
        object car = ExpandInner(tp.car, bindings, gensymMap, pvars);
        object cdr = ExpandInner(tp.cdr, bindings, gensymMap, pvars);
        // Always create a fresh Pair without source position so that
        // definition-site positions from parsed templates do not leak
        // into expanded output (the expander attaches use-site positions).
        if (car == tp.car && cdr == tp.cdr && tp.pos == null) return template;
        return new Pair(car, cdr);
    }

    /// <summary>
    /// Expand a template with no ellipsis processing (for ellipsis escape).
    /// Free identifiers are still renamed.
    /// </summary>
    private object ExpandNoEllipsis(object template, List<Binding> bindings,
                                    Dictionary<string, string> gensymMap, HashSet<string> pvars)
    {
        // SyntaxObject identifier
        if (template is SyntaxObject stx && stx.IsIdentifier)
        {
            string name = stx.SymbolName;
            var binding = FindBindingByIdentity(template, name, bindings);
            if (binding != null && !binding.IsEllipsis)
                return binding.Value!;
            return template;
        }
        if (template is SyntaxObject so)
            template = so.Datum;
        // Plain symbol: pass through
        if (Value.IsSymbol(template))
            return template;
        if (!Value.IsPair(template) || template == Value.NIL) return template;
        Pair tp = Value.AsPair(template);
        object car = ExpandNoEllipsis(tp.car, bindings, gensymMap, pvars);
        object cdr = ExpandNoEllipsis(tp.cdr, bindings, gensymMap, pvars);
        if (car == tp.car && cdr == tp.cdr && tp.pos == null) return template;
        return new Pair(car, cdr);
    }

    /// <summary>Extract identifier name from a plain symbol or SyntaxObject identifier.</summary>
    private static string? GetIdentName(object obj)
    {
        if (obj is SyntaxObject stx && stx.IsIdentifier) return stx.SymbolName;
        if (Value.IsSymbol(obj)) return Value.AsSymbol(obj);
        return null;
    }

    // ---- List Traversal Helpers ----


    /// <summary>Is this a pair? (SyntaxObjects only wrap identifiers, never pairs.)</summary>
    private static bool IsPair(object x)
    {
        return Value.IsPair(x);
    }

    /// <summary>Is this NIL?</summary>
    private static bool IsNil(object x)
    {
        return x == Value.NIL;
    }

    /// <summary>Get the car of a pair.</summary>
    private static object Car(object x)
    {
        return Value.AsPair(x).car;
    }

    /// <summary>Get the cdr of a pair.</summary>
    private static object Cdr(object x)
    {
        return Value.AsPair(x).cdr;
    }

    /// <summary>Count elements in a list.</summary>
    private static int? ListLength(object x)
    {
        int n = 0;
        while (true)
        {
            if (x == Value.NIL) return n;
            if (!Value.IsPair(x)) return null;
            n++;
            x = Value.AsPair(x).cdr;
        }
    }

    /// <summary>Take first n elements from a list.</summary>
    private static List<object> ListTake(object ls, int n)
    {
        var result = new List<object>();
        for (int i = 0; i < n; i++)
        {
            if (!Value.IsPair(ls) || ls == Value.NIL) break;
            result.Add(Value.AsPair(ls).car);
            ls = Value.AsPair(ls).cdr;
        }
        return result;
    }

    /// <summary>Drop first n elements from a list.</summary>
    private static object ListDrop(object ls, int n)
    {
        for (int i = 0; i < n; i++)
        {
            if (!Value.IsPair(ls) || ls == Value.NIL) break;
            ls = Value.AsPair(ls).cdr;
        }
        return ls;
    }

    /// <summary>Check if a pattern element is a literal using bound-identifier=? semantics.
    /// Per the sets-of-scopes algorithm, two identifiers with the same name but
    /// different scopes are distinct — a pattern identifier is only a literal if it
    /// has the same name AND same scope set as an entry in the literals list.</summary>
    private bool IsLiteralIdentifier(object patternElem, BindingTable? bindingTable = null)
    {
        foreach (var lit in literals)
        {
            // Both SyntaxObjects: use BoundIdEq (same name + same scope set)
            if (patternElem is SyntaxObject pStx && lit is SyntaxObject lStx)
            {
                if (pStx.IsIdentifier && lStx.IsIdentifier
                    && SyntaxObject.BoundIdEq(pStx, lStx))
                    return true;
            }
            // Both must be SyntaxObjects — plain symbols indicate a wrapping bug upstream
            else
            {
                string? pName = GetIdentName(patternElem);
                string? lName = GetIdentName(lit);
                if (pName != null || lName != null)
                    throw new SchemeError("internal: IsLiteralIdentifier received non-SyntaxObject identifier: pattern=~a, literal=~a", patternElem, lit);
            }
        }
        return false;
    }

    /// <summary>Collect pattern variable names from a pattern.</summary>
    private List<string> CollectPatternVars(object pattern)
    {
        var vars = new List<string>();
        CollectPatternVarsInner(pattern, vars);
        return vars;
    }

    private void CollectPatternVarsInner(object pattern, List<string> vars)
    {
        if (IsNil(pattern)) return;
        // Handle SyntaxObject and plain symbol identifiers
        string? name = GetIdentName(pattern);
        if (name != null)
        {
            if (name == "_" && !underscoreIsLiteral) return;
            if (name == ellipsis) return;
            if (IsLiteralIdentifier(pattern)) return;
            if (!vars.Contains(name)) vars.Add(name);
            return;
        }
        if (!IsPair(pattern)) return;
        object pCar = Car(pattern);
        object pCdr = Cdr(pattern);
        // Skip ellipsis following a sub-pattern
        if (IsPair(pCdr))
        {
            string? cdrCarName = GetIdentName(Car(pCdr));
            if (cdrCarName == ellipsis)
            {
                CollectPatternVarsInner(pCar, vars);
                CollectPatternVarsInner(Cdr(pCdr), vars);
                return;
            }
        }
        CollectPatternVarsInner(pCar, vars);
        CollectPatternVarsInner(pCdr, vars);
    }

    private Binding? FindBinding(string name, List<Binding> bindings)
    {
        for (int i = 0; i < bindings.Count; i++)
            if (bindings[i].Name == name) return bindings[i];
        return null;
    }

    /// <summary>
    /// Find a binding matching both name AND identity (marks).
    /// When both the template identifier and the binding's pattern identifier are SyntaxObjects,
    /// use BoundIdEq to check they have the same marks (same expansion context).
    /// </summary>
    private Binding? FindBindingByIdentity(object templateIdent, string name, List<Binding> bindings)
    {
        for (int i = 0; i < bindings.Count; i++)
        {
            if (bindings[i].Name != name) continue;
            // If both are SyntaxObjects, use BoundIdEq for mark comparison
            if (templateIdent is SyntaxObject tStx && bindings[i].Identifier is SyntaxObject pStx)
            {
                if (SyntaxObject.BoundIdEq(tStx, pStx))
                    return bindings[i];
                // Same name but different marks → not the same binding
                continue;
            }
            // Both must be SyntaxObjects — plain symbol bindings indicate a wrapping bug upstream
            if (!(bindings[i].Identifier is SyntaxObject))
                throw new SchemeError("internal: FindBindingByIdentity found plain symbol binding for: ~a", name);
            // Template is plain but binding has SyntaxObject → no match
        }
        return null;
    }

    private List<Binding> FindEllipsisPvars(object template, List<Binding> bindings)
    {
        var names = new HashSet<string>();
        CollectTemplateVarRefs(template, names);
        var result = new List<Binding>();
        foreach (var b in bindings)
        {
            if (b.IsEllipsis && names.Contains(b.Name))
                result.Add(b);
        }
        return result;
    }

    private void CollectTemplateVarRefs(object template, HashSet<string> names)
    {
        if (template is SyntaxObject stx && stx.IsIdentifier)
            { names.Add(stx.SymbolName); return; }
        if (template is SyntaxObject so)
            template = so.Datum;
        if (Value.IsSymbol(template)) { names.Add(Value.AsSymbol(template)); return; }
        if (!Value.IsPair(template) || template == Value.NIL) return;
        Pair tp = Value.AsPair(template);
        CollectTemplateVarRefs(tp.car, names);
        CollectTemplateVarRefs(tp.cdr, names);
    }

    private static object VectorToList(object[] vec)
    {
        object result = Value.NIL;
        for (int i = vec.Length - 1; i >= 0; i--)
            result = new Pair(vec[i], result);
        return result;
    }

    private static object[] ListToVector(object list)
    {
        var elems = new List<object>();
        while (list != Value.NIL && Value.IsPair(list))
        {
            elems.Add(Value.AsPair(list).car);
            list = Value.AsPair(list).cdr;
        }
        return elems.ToArray();
    }

    // ---- Parsing ----

    /// <summary>
    /// Parse a syntax-rules form and create a SyntaxRulesTransformer.
    /// Form: (syntax-rules (literal ...) (pattern template) ...)
    /// Or:   (syntax-rules ellipsis (literal ...) (pattern template) ...)
    /// The first element (syntax-rules keyword) should already be stripped.
    /// </summary>
    public static SyntaxRulesTransformer Parse(object args, string defModule, Modules modules,
                                                Dictionary<string, (int frame, int index)>? localVars = null)
    {
        // In sets-of-scopes, pairs are never wrapped in SyntaxObject
        if (args == Value.NIL || !Value.IsPair(args))
            throw new SchemeError("syntax-rules: invalid form");

        Pair argsPair = Value.AsPair(args);
        string? customEllipsis = null;
        object rest = args;

        // Check for custom ellipsis: (syntax-rules <identifier> (<literals>) <rules>...)
        string? firstArgName = GetIdentName(argsPair.car);
        if (firstArgName != null && firstArgName != "_")
        {
            // First arg is an identifier (not a list) — it's a custom ellipsis
            string potentialEllipsis = firstArgName;
            // Make sure the next arg is a list (the literals)
            object nextArg = argsPair.cdr;
            if (Value.IsPair(nextArg))
            {
                object nextCar = Value.AsPair(nextArg).car;
                if (Value.IsPair(nextCar) || nextCar == Value.NIL)
                {
                    customEllipsis = potentialEllipsis;
                    rest = nextArg;
                }
            }
        }

        // Parse literals list
        Pair restPair = Value.AsPair(rest);
        var literals = new List<object>();
        object litList = restPair.car;
        while (litList != Value.NIL && Value.IsPair(litList))
        {
            literals.Add(Value.AsPair(litList).car); // Store as-is (may be SyntaxObject)
            litList = Value.AsPair(litList).cdr;
        }

        // Parse rules
        var rules = new List<Rule>();
        object ruleList = restPair.cdr;
        while (ruleList != Value.NIL && Value.IsPair(ruleList))
        {
            object ruleObj = Value.AsPair(ruleList).car;
            Pair rule = Value.AsPair(ruleObj);
            // rule = (pattern template)
            object pattern = rule.car;
            object ruleCdr = rule.cdr;
            object template = Value.IsPair(ruleCdr) ? Value.AsPair(ruleCdr).car : Value.NIL;
            // Skip the first element of the pattern (macro name)
            if (Value.IsPair(pattern))
                pattern = Value.AsPair(pattern).cdr;
            rules.Add(new Rule(pattern, template)); // Store as-is (may contain SyntaxObjects)
            ruleList = Value.AsPair(ruleList).cdr;
        }

        return new SyntaxRulesTransformer(
            literals.ToArray(),
            rules.ToArray(),
            customEllipsis ?? "...",
            defModule,
            localVars);
    }

    /// <summary>A pattern/template pair in a syntax-rules form.</summary>
    public class Rule
    {
        public readonly object Pattern;   // Pattern (cdr of the original, skipping macro name)
        public readonly object Template;  // Template

        public Rule(object pattern, object template)
        {
            this.Pattern = pattern;
            this.Template = template;
        }
    }

    /// <summary>A binding from pattern matching.</summary>
    public class Binding
    {
        public readonly string Name;
        public readonly object? Identifier;  // Original identifier (SyntaxObject or plain symbol) from pattern
        public readonly object? Value;       // For non-ellipsis: the matched datum
        public readonly List<object>? Values; // For ellipsis: list of matched datums
        public readonly bool IsEllipsis;

        public Binding(string name, object value, bool isEllipsis = false, object? identifier = null)
        {
            this.Name = name;
            this.Identifier = identifier;
            if (isEllipsis)
            {
                this.Values = (List<object>)value;
                this.Value = null;
                this.IsEllipsis = true;
            }
            else
            {
                this.Value = value;
                this.Values = null;
                this.IsEllipsis = false;
            }
        }
    }
}
