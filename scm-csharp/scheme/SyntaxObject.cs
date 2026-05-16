namespace scheme;

/// <summary>
/// A syntax object wraps an identifier (symbol) with a set of scopes,
/// implementing the sets-of-scopes macro hygiene model (Flatt 2016).
///
/// Only symbols are wrapped in SyntaxObject. Pairs and vectors are never
/// wrapped — scope operations recurse into their elements directly.
/// Constants (numbers, booleans, chars, strings) pass through unwrapped.
/// </summary>
public class SyntaxObject
{
    /// <summary>The underlying datum: always a symbol (string) for identifiers.</summary>
    public readonly object Datum;

    /// <summary>The scope set for this identifier.</summary>
    public readonly ScopeSet Scopes;

    /// <summary>Source location, if available.</summary>
    public readonly SourcePos? Pos;

    public SyntaxObject(object datum, ScopeSet scopes, SourcePos? pos)
    {
        this.Datum = datum;
        this.Scopes = scopes;
        this.Pos = pos;
    }

    public SyntaxObject(object datum, ScopeSet scopes) : this(datum, scopes, null) { }

    public override string ToString()
    {
        if (IsIdentifier)
        {
            return Scopes.Count > 0
                ? "#<syntax " + SymbolName + " " + Scopes + ">"
                : "#<syntax " + SymbolName + ">";
        }
        return "#<syntax " + (Datum?.ToString() ?? "?") + ">";
    }

    /// <summary>True if this syntax object is an identifier (wraps a symbol).</summary>
    public bool IsIdentifier => Value.IsSymbol(Datum);

    /// <summary>For identifiers, returns the symbol name.</summary>
    public string SymbolName => Value.AsSymbol(Datum);

    // ---- Static operations ----

    /// <summary>Generate a fresh unique scope ID.</summary>
    public static int FreshScope()
    {
        return ScopeSet.FreshScope();
    }

    /// <summary>
    /// Wrap a raw S-expression (datum) into syntax objects recursively.
    /// Symbols become SyntaxObject identifiers. Pairs become Pairs of wrapped
    /// elements (NOT wrapped in SyntaxObject themselves). Vectors get wrapped
    /// elements. Constants pass through unwrapped.
    /// </summary>
    public static object WrapDatum(object datum, ScopeSet scopes, SourcePos? pos)
    {
        if (Value.IsSymbol(datum))
        {
            return new SyntaxObject(datum, scopes, pos);
        }
        if (datum is Pair p)
        {
            var wrappedCar = WrapDatum(p.car, scopes, p.pos);
            var wrappedCdr = WrapDatum(p.cdr, scopes, null);
            return new Pair(wrappedCar, wrappedCdr, p.pos ?? pos);
        }
        if (Value.IsVector(datum))
        {
            var vec = Value.AsVector(datum);
            var newVec = new object[vec.Length];
            for (int i = 0; i < vec.Length; i++)
                newVec[i] = WrapDatum(vec[i], scopes, pos);
            return newVec;
        }
        // Constants (numbers, booleans, chars, strings, NIL) pass through unwrapped
        return datum;
    }

    /// <summary>
    /// Add a scope to a syntax object or raw datum, recursively.
    /// SyntaxObject → new SyntaxObject with scopes.Add(scope).
    /// Pair → recurse into car/cdr. Constants pass through.
    /// </summary>
    public static object AddScope(object stx, int scope)
    {
        if (stx is SyntaxObject so)
        {
            return new SyntaxObject(so.Datum, so.Scopes.Add(scope), so.Pos);
        }
        if (stx is Pair p)
        {
            var car = AddScope(p.car, scope);
            var cdr = AddScope(p.cdr, scope);
            if (car == p.car && cdr == p.cdr) return stx;
            return new Pair(car, cdr, p.pos);
        }
        if (Value.IsVector(stx))
        {
            var vec = Value.AsVector(stx);
            var newVec = new object[vec.Length];
            bool changed = false;
            for (int i = 0; i < vec.Length; i++)
            {
                newVec[i] = AddScope(vec[i], scope);
                if (newVec[i] != vec[i]) changed = true;
            }
            return changed ? newVec : stx;
        }
        return stx;
    }

    /// <summary>
    /// Flip a scope on a syntax object or raw datum, recursively.
    /// SyntaxObject → new SyntaxObject with scopes.Flip(scope).
    /// Pair → recurse into car/cdr. Constants pass through.
    /// </summary>
    public static object FlipScope(object stx, int scope)
    {
        if (stx is SyntaxObject so)
        {
            return new SyntaxObject(so.Datum, so.Scopes.Flip(scope), so.Pos);
        }
        if (stx is Pair p)
        {
            var car = FlipScope(p.car, scope);
            var cdr = FlipScope(p.cdr, scope);
            if (car == p.car && cdr == p.cdr) return stx;
            return new Pair(car, cdr, p.pos);
        }
        if (Value.IsVector(stx))
        {
            var vec = Value.AsVector(stx);
            var newVec = new object[vec.Length];
            bool changed = false;
            for (int i = 0; i < vec.Length; i++)
            {
                newVec[i] = FlipScope(vec[i], scope);
                if (newVec[i] != vec[i]) changed = true;
            }
            return changed ? newVec : stx;
        }
        return stx;
    }

    /// <summary>
    /// Strip syntax objects back to plain S-expressions, resolving identifiers
    /// through the binding table. Resolved identifiers use their ResolvedName;
    /// unresolved identifiers use their symbol name.
    /// </summary>
    public static object Strip(object stx, BindingTable bindingTable)
    {
        if (stx is SyntaxObject so)
        {
            if (so.IsIdentifier)
            {
                var resolved = Resolve(so, bindingTable);
                if (resolved != null)
                    return resolved.ResolvedName;
                return so.SymbolName;
            }
            // Should not happen in sets-of-scopes (only symbols are wrapped),
            // but handle gracefully
            return Strip(so.Datum, bindingTable);
        }
        if (stx is Pair p)
        {
            var car = Strip(p.car, bindingTable);
            var cdr = Strip(p.cdr, bindingTable);
            if (car == p.car && cdr == p.cdr)
                return p;
            return new Pair(car, cdr, p.pos);
        }
        if (Value.IsVector(stx))
        {
            var vec = Value.AsVector(stx);
            var newVec = new object[vec.Length];
            bool changed = false;
            for (int i = 0; i < vec.Length; i++)
            {
                newVec[i] = Strip(vec[i], bindingTable);
                if (newVec[i] != vec[i]) changed = true;
            }
            return changed ? newVec : stx;
        }
        return stx;
    }

    /// <summary>
    /// Strip syntax objects back to plain S-expressions without resolving
    /// through a binding table. Identifiers are stripped to their symbol name.
    /// For backward compatibility.
    /// </summary>
    public static object Strip(object stx)
    {
        if (stx is SyntaxObject so)
        {
            if (so.IsIdentifier)
                return so.SymbolName;
            return Strip(so.Datum);
        }
        if (stx is Pair p)
        {
            var car = Strip(p.car);
            var cdr = Strip(p.cdr);
            if (car == p.car && cdr == p.cdr)
                return p;
            return new Pair(car, cdr, p.pos);
        }
        if (Value.IsVector(stx))
        {
            var vec = Value.AsVector(stx);
            var newVec = new object[vec.Length];
            bool changed = false;
            for (int i = 0; i < vec.Length; i++)
            {
                newVec[i] = Strip(vec[i]);
                if (newVec[i] != vec[i]) changed = true;
            }
            return changed ? newVec : stx;
        }
        return stx;
    }

    /// <summary>
    /// Resolve an identifier through the binding table.
    /// Returns the ResolvedBinding, or null if unbound.
    /// </summary>
    public static ResolvedBinding? Resolve(SyntaxObject id, BindingTable bindingTable)
    {
        if (!id.IsIdentifier)
            return null;
        return bindingTable.Resolve(id.SymbolName, id.Scopes);
    }

    /// <summary>
    /// Two identifiers are free-identifier=? if they resolve to the same binding.
    /// Both unbound with same name → true. Both bound with same label → true.
    /// Otherwise false.
    /// </summary>
    public static bool FreeIdEq(SyntaxObject a, SyntaxObject b, BindingTable bindingTable)
    {
        if (!a.IsIdentifier || !b.IsIdentifier) return false;
        var bindA = Resolve(a, bindingTable);
        var bindB = Resolve(b, bindingTable);
        // Both unbound → same name means same binding (R7RS 4.3.2)
        if (bindA == null && bindB == null)
            return a.SymbolName == b.SymbolName;
        if (bindA == null || bindB == null)
            return false;
        // Compare by binding identity via label
        return bindA.Label == bindB.Label;
    }

    /// <summary>
    /// Two identifiers are bound-identifier=? if they have the same name
    /// and the same scope set.
    /// </summary>
    public static bool BoundIdEq(SyntaxObject a, SyntaxObject b)
    {
        if (!a.IsIdentifier || !b.IsIdentifier) return false;
        if (a.SymbolName != b.SymbolName) return false;
        return a.Scopes.SetEquals(b.Scopes);
    }

    /// <summary>
    /// Extract the source position from a syntax object or pair.
    /// </summary>
    public static SourcePos? GetPos(object stx)
    {
        if (stx is SyntaxObject so) return so.Pos;
        if (stx is Pair p) return p.pos;
        return null;
    }

    /// <summary>
    /// Get the datum of a syntax object, or the value itself if not wrapped.
    /// </summary>
    public static object GetDatum(object stx)
    {
        if (stx is SyntaxObject so) return so.Datum;
        return stx;
    }

    /// <summary>
    /// Check if the given object is an identifier (a syntax object wrapping a symbol).
    /// </summary>
    public static bool IsIdentifierObj(object stx)
    {
        return stx is SyntaxObject so && so.IsIdentifier;
    }
}
