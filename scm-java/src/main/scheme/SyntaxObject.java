package scheme;

/**
 * A syntax object wraps an identifier (symbol) with a set of scopes,
 * implementing the sets-of-scopes macro hygiene model (Flatt 2016).
 *
 * Only identifiers (symbols) are wrapped in SyntaxObject. Pairs and
 * vectors are NOT wrapped — scope operations recurse into their elements.
 * Constants (numbers, booleans, chars, strings) pass through unchanged.
 */
public class SyntaxObject {
    /** The underlying datum: always a symbol (String) for identifiers. */
    public final Object datum;

    /** The scope set for this identifier. */
    public final ScopeSet scopes;

    /** Source location, if available. */
    public final SourcePos pos;

    public SyntaxObject(Object datum, ScopeSet scopes, SourcePos pos) {
        this.datum = datum;
        this.scopes = scopes;
        this.pos = pos;
    }

    public SyntaxObject(Object datum, ScopeSet scopes) {
        this(datum, scopes, null);
    }

    @Override
    public String toString() {
        if (isIdentifier()) {
            if (scopes.count() > 0) {
                return "#<syntax " + symbolName() + " " + scopes + ">";
            }
            return "#<syntax " + symbolName() + ">";
        }
        return "#<syntax " + (datum != null ? datum.toString() : "?") + ">";
    }

    /** True if this syntax object is an identifier (wraps a symbol). */
    public boolean isIdentifier() {
        return Value.isSymbol(datum);
    }

    /** For identifiers, returns the symbol name. */
    public String symbolName() {
        return Value.asSymbol(datum);
    }

    // ---- Static operations ----

    /** Generate a fresh unique scope ID. Delegates to ScopeSet. */
    public static int freshScope() {
        return ScopeSet.freshScope();
    }

    /**
     * Wrap a raw S-expression (datum) into syntax objects recursively.
     * Symbols become SyntaxObject identifiers with the given scopes.
     * Pairs become Pairs with wrapped elements (NOT wrapped in SyntaxObject).
     * Vectors become vectors with wrapped elements (NOT wrapped in SyntaxObject).
     * Constants pass through unwrapped.
     */
    public static Object wrapDatum(Object datum, ScopeSet scopes, SourcePos pos) {
        if (Value.isSymbol(datum)) {
            return new SyntaxObject(datum, scopes, pos);
        }
        if (datum instanceof Pair) {
            Pair p = (Pair) datum;
            Object wrappedCar = wrapDatum(p.car, scopes, p.pos);
            Object wrappedCdr = wrapDatum(p.cdr, scopes, null);
            Pair newPair = new Pair(wrappedCar, wrappedCdr);
            newPair.pos = p.pos != null ? p.pos : pos;
            return newPair;
        }
        if (Value.isVector(datum)) {
            Object[] vec = Value.asVector(datum);
            Object[] newVec = new Object[vec.length];
            for (int i = 0; i < vec.length; i++)
                newVec[i] = wrapDatum(vec[i], scopes, pos);
            return newVec;
        }
        // Constants (numbers, booleans, chars, strings, NIL) pass through unwrapped
        return datum;
    }

    /**
     * Add a scope to a syntax object or raw datum, recursively.
     * SyntaxObject → new SyntaxObject with scopes.add(scope).
     * Pair → recurse into car/cdr.
     * Vector → recurse into elements.
     * Constant → pass through.
     */
    public static Object addScope(Object stx, int scope) {
        if (stx instanceof SyntaxObject) {
            SyntaxObject so = (SyntaxObject) stx;
            return new SyntaxObject(so.datum, so.scopes.add(scope), so.pos);
        }
        if (stx instanceof Pair) {
            Pair p = (Pair) stx;
            Object car = addScope(p.car, scope);
            Object cdr = addScope(p.cdr, scope);
            if (car == p.car && cdr == p.cdr) return stx;
            Pair result = new Pair(car, cdr);
            result.pos = p.pos;
            return result;
        }
        if (Value.isVector(stx)) {
            Object[] vec = Value.asVector(stx);
            Object[] newVec = new Object[vec.length];
            boolean changed = false;
            for (int i = 0; i < vec.length; i++) {
                newVec[i] = addScope(vec[i], scope);
                if (newVec[i] != vec[i]) changed = true;
            }
            return changed ? newVec : stx;
        }
        return stx;
    }

    /**
     * Flip a scope on a syntax object or raw datum, recursively.
     * SyntaxObject → new SyntaxObject with scopes.flip(scope).
     * Pair → recurse into car/cdr.
     * Vector → recurse into elements.
     * Constant → pass through.
     */
    public static Object flipScope(Object stx, int scope) {
        if (stx instanceof SyntaxObject) {
            SyntaxObject so = (SyntaxObject) stx;
            return new SyntaxObject(so.datum, so.scopes.flip(scope), so.pos);
        }
        if (stx instanceof Pair) {
            Pair p = (Pair) stx;
            Object car = flipScope(p.car, scope);
            Object cdr = flipScope(p.cdr, scope);
            if (car == p.car && cdr == p.cdr) return stx;
            Pair result = new Pair(car, cdr);
            result.pos = p.pos;
            return result;
        }
        if (Value.isVector(stx)) {
            Object[] vec = Value.asVector(stx);
            Object[] newVec = new Object[vec.length];
            boolean changed = false;
            for (int i = 0; i < vec.length; i++) {
                newVec[i] = flipScope(vec[i], scope);
                if (newVec[i] != vec[i]) changed = true;
            }
            return changed ? newVec : stx;
        }
        return stx;
    }

    /**
     * Strip syntax objects back to plain S-expressions.
     * Identifiers are resolved via the binding table to their resolved names.
     */
    public static Object strip(Object stx, BindingTable bindingTable) {
        if (stx instanceof SyntaxObject) {
            SyntaxObject so = (SyntaxObject) stx;
            if (so.isIdentifier()) {
                if (bindingTable != null) {
                    ResolvedBinding resolved = resolve(so, bindingTable);
                    if (resolved != null)
                        return resolved.resolvedName;
                }
                return so.symbolName();
            }
            return strip(so.datum, bindingTable);
        }
        if (stx instanceof Pair) {
            Pair p = (Pair) stx;
            Object car = strip(p.car, bindingTable);
            Object cdr = strip(p.cdr, bindingTable);
            if (car == p.car && cdr == p.cdr)
                return p;
            Pair result = new Pair(car, cdr);
            result.pos = p.pos;
            return result;
        }
        if (Value.isVector(stx)) {
            Object[] vec = Value.asVector(stx);
            Object[] newVec = new Object[vec.length];
            boolean changed = false;
            for (int i = 0; i < vec.length; i++) {
                newVec[i] = strip(vec[i], bindingTable);
                if (newVec[i] != vec[i]) changed = true;
            }
            return changed ? newVec : stx;
        }
        return stx;
    }

    /**
     * Strip syntax objects back to plain S-expressions without resolving names.
     */
    public static Object strip(Object stx) {
        return strip(stx, null);
    }

    /**
     * Resolve an identifier to its binding via the binding table.
     * Returns the ResolvedBinding, or null if unbound.
     */
    public static ResolvedBinding resolve(SyntaxObject id, BindingTable bindingTable) {
        if (!id.isIdentifier())
            return null;
        return bindingTable.resolve(id.symbolName(), id.scopes);
    }

    /**
     * Two identifiers are free-identifier=? if they resolve to the same binding.
     */
    public static boolean freeIdEq(SyntaxObject a, SyntaxObject b, BindingTable bindingTable) {
        if (!a.isIdentifier() || !b.isIdentifier()) return false;
        ResolvedBinding bindA = resolve(a, bindingTable);
        ResolvedBinding bindB = resolve(b, bindingTable);
        if (bindA == null && bindB == null)
            return a.symbolName().equals(b.symbolName());
        if (bindA == null || bindB == null)
            return false;
        return bindA.label.equals(bindB.label);
    }

    /**
     * Two identifiers are bound-identifier=? if they have the same name
     * and the same scope set.
     */
    public static boolean boundIdEq(SyntaxObject a, SyntaxObject b) {
        if (!a.isIdentifier() || !b.isIdentifier()) return false;
        if (!a.symbolName().equals(b.symbolName())) return false;
        return a.scopes.setEquals(b.scopes);
    }

    /** Extract the source position from a syntax object or pair. */
    public static SourcePos getPos(Object stx) {
        if (stx instanceof SyntaxObject) {
            SyntaxObject so = (SyntaxObject) stx;
            return so.pos;
        }
        if (stx instanceof Pair) return ((Pair) stx).pos;
        return null;
    }

    /** Get the datum of a syntax object, or the value itself if not wrapped. */
    public static Object getDatum(Object stx) {
        if (stx instanceof SyntaxObject) return ((SyntaxObject) stx).datum;
        return stx;
    }

    /** Check if the given object is an identifier (a syntax object wrapping a symbol). */
    public static boolean isIdentifierObj(Object stx) {
        return stx instanceof SyntaxObject && ((SyntaxObject) stx).isIdentifier();
    }
}
