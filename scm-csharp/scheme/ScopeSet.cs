using System;
using System.Threading;

namespace scheme;

/// <summary>
/// An immutable set of scope identifiers, implemented as a sorted int array.
/// Used in the sets-of-scopes macro hygiene model (Flatt 2016).
/// Each identifier in the syntax tree carries a ScopeSet that accumulates
/// as the identifier passes through binding contexts and macro expansions.
/// </summary>
public class ScopeSet
{
    public static readonly ScopeSet Empty = new ScopeSet(Array.Empty<int>());

    private readonly int[] scopes; // sorted, immutable

    private static int scopeCounter = 0;

    /// <summary>Generate a fresh unique scope ID (thread-safe).</summary>
    public static int FreshScope()
    {
        return Interlocked.Increment(ref scopeCounter);
    }

    public ScopeSet(int[] sortedScopes)
    {
        this.scopes = sortedScopes;
    }

    public int Count => scopes.Length;

    /// <summary>Create a ScopeSet with a single scope.</summary>
    public static ScopeSet Of(int scope)
    {
        return new ScopeSet(new[] { scope });
    }

    /// <summary>Create a ScopeSet from multiple scopes (will be sorted).</summary>
    public static ScopeSet Of(params int[] scopeIds)
    {
        var sorted = (int[])scopeIds.Clone();
        Array.Sort(sorted);
        return new ScopeSet(sorted);
    }

    /// <summary>Add a scope. Returns a new ScopeSet with the scope inserted.</summary>
    public ScopeSet Add(int scope)
    {
        // Binary search for insertion point
        int idx = Array.BinarySearch(scopes, scope);
        if (idx >= 0) return this; // already present

        int insertAt = ~idx;
        var newScopes = new int[scopes.Length + 1];
        Array.Copy(scopes, 0, newScopes, 0, insertAt);
        newScopes[insertAt] = scope;
        Array.Copy(scopes, insertAt, newScopes, insertAt + 1, scopes.Length - insertAt);
        return new ScopeSet(newScopes);
    }

    /// <summary>Remove a scope. Returns a new ScopeSet without the scope.</summary>
    public ScopeSet Remove(int scope)
    {
        int idx = Array.BinarySearch(scopes, scope);
        if (idx < 0) return this; // not present

        var newScopes = new int[scopes.Length - 1];
        Array.Copy(scopes, 0, newScopes, 0, idx);
        Array.Copy(scopes, idx + 1, newScopes, idx, scopes.Length - idx - 1);
        return new ScopeSet(newScopes);
    }

    /// <summary>Flip a scope: add if absent, remove if present.</summary>
    public ScopeSet Flip(int scope)
    {
        int idx = Array.BinarySearch(scopes, scope);
        if (idx >= 0)
            return Remove(scope);
        return Add(scope);
    }

    /// <summary>Check if this set contains a scope.</summary>
    public bool Contains(int scope)
    {
        return Array.BinarySearch(scopes, scope) >= 0;
    }

    /// <summary>
    /// Check if this set is a subset of another.
    /// Uses two-pointer walk on sorted arrays, O(m+n).
    /// </summary>
    public bool IsSubsetOf(ScopeSet other)
    {
        if (this.scopes.Length > other.scopes.Length) return false;
        if (this.scopes.Length == 0) return true;

        int i = 0, j = 0;
        while (i < this.scopes.Length && j < other.scopes.Length)
        {
            if (this.scopes[i] == other.scopes[j])
            {
                i++;
                j++;
            }
            else if (this.scopes[i] > other.scopes[j])
            {
                j++;
            }
            else
            {
                return false; // this.scopes[i] < other.scopes[j], not found
            }
        }
        return i == this.scopes.Length;
    }

    /// <summary>Check equality with another ScopeSet.</summary>
    public bool SetEquals(ScopeSet other)
    {
        if (this.scopes.Length != other.scopes.Length) return false;
        for (int i = 0; i < scopes.Length; i++)
        {
            if (scopes[i] != other.scopes[i]) return false;
        }
        return true;
    }

    public override bool Equals(object? obj)
    {
        return obj is ScopeSet other && SetEquals(other);
    }

    public override int GetHashCode()
    {
        int hash = 17;
        for (int i = 0; i < scopes.Length; i++)
            hash = hash * 31 + scopes[i];
        return hash;
    }

    public override string ToString()
    {
        if (scopes.Length == 0) return "{}";
        return "{" + string.Join(",", scopes) + "}";
    }

    /// <summary>Get the raw scope array (for debugging).</summary>
    internal int[] GetScopes() => scopes;
}
