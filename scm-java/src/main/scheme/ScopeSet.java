package scheme;

import java.util.Arrays;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * An immutable set of scope identifiers, implemented as a sorted int array.
 * Used in the sets-of-scopes macro hygiene model (Flatt 2016).
 * Each identifier in the syntax tree carries a ScopeSet that accumulates
 * as the identifier passes through binding contexts and macro expansions.
 */
public class ScopeSet {
    public static final ScopeSet EMPTY = new ScopeSet(new int[0]);

    private final int[] scopes; // sorted, immutable

    private static final AtomicInteger scopeCounter = new AtomicInteger(0);

    /** Generate a fresh unique scope ID (thread-safe). */
    public static int freshScope() {
        return scopeCounter.incrementAndGet();
    }

    public ScopeSet(int[] sortedScopes) {
        this.scopes = sortedScopes;
    }

    public int count() {
        return scopes.length;
    }

    /** Create a ScopeSet with a single scope. */
    public static ScopeSet of(int scope) {
        return new ScopeSet(new int[] { scope });
    }

    /** Create a ScopeSet from multiple scopes (will be sorted). */
    public static ScopeSet of(int... scopeIds) {
        int[] sorted = scopeIds.clone();
        Arrays.sort(sorted);
        return new ScopeSet(sorted);
    }

    /** Add a scope. Returns a new ScopeSet with the scope inserted. */
    public ScopeSet add(int scope) {
        int idx = Arrays.binarySearch(scopes, scope);
        if (idx >= 0) return this; // already present

        int insertAt = -(idx + 1);
        int[] newScopes = new int[scopes.length + 1];
        System.arraycopy(scopes, 0, newScopes, 0, insertAt);
        newScopes[insertAt] = scope;
        System.arraycopy(scopes, insertAt, newScopes, insertAt + 1, scopes.length - insertAt);
        return new ScopeSet(newScopes);
    }

    /** Remove a scope. Returns a new ScopeSet without the scope. */
    public ScopeSet remove(int scope) {
        int idx = Arrays.binarySearch(scopes, scope);
        if (idx < 0) return this; // not present

        int[] newScopes = new int[scopes.length - 1];
        System.arraycopy(scopes, 0, newScopes, 0, idx);
        System.arraycopy(scopes, idx + 1, newScopes, idx, scopes.length - idx - 1);
        return new ScopeSet(newScopes);
    }

    /** Flip a scope: add if absent, remove if present. */
    public ScopeSet flip(int scope) {
        int idx = Arrays.binarySearch(scopes, scope);
        if (idx >= 0)
            return remove(scope);
        return add(scope);
    }

    /** Check if this set contains a scope. */
    public boolean contains(int scope) {
        return Arrays.binarySearch(scopes, scope) >= 0;
    }

    /**
     * Check if this set is a subset of another.
     * Uses two-pointer walk on sorted arrays, O(m+n).
     */
    public boolean isSubsetOf(ScopeSet other) {
        if (this.scopes.length > other.scopes.length) return false;
        if (this.scopes.length == 0) return true;

        int i = 0, j = 0;
        while (i < this.scopes.length && j < other.scopes.length) {
            if (this.scopes[i] == other.scopes[j]) {
                i++;
                j++;
            } else if (this.scopes[i] > other.scopes[j]) {
                j++;
            } else {
                return false; // this.scopes[i] < other.scopes[j], not found
            }
        }
        return i == this.scopes.length;
    }

    /** Check equality with another ScopeSet. */
    public boolean setEquals(ScopeSet other) {
        if (this.scopes.length != other.scopes.length) return false;
        for (int i = 0; i < scopes.length; i++) {
            if (scopes[i] != other.scopes[i]) return false;
        }
        return true;
    }

    @Override
    public boolean equals(Object obj) {
        return obj instanceof ScopeSet && setEquals((ScopeSet) obj);
    }

    @Override
    public int hashCode() {
        int hash = 17;
        for (int i = 0; i < scopes.length; i++)
            hash = hash * 31 + scopes[i];
        return hash;
    }

    @Override
    public String toString() {
        if (scopes.length == 0) return "{}";
        StringBuilder sb = new StringBuilder("{");
        for (int i = 0; i < scopes.length; i++) {
            if (i > 0) sb.append(",");
            sb.append(scopes[i]);
        }
        sb.append("}");
        return sb.toString();
    }

    /** Get the raw scope array (for debugging). */
    int[] getScopes() {
        return scopes;
    }
}
