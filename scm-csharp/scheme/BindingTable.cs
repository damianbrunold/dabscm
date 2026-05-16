using System.Collections.Generic;

namespace scheme;

/// <summary>
/// Thread-safe binding table for the sets-of-scopes macro hygiene model.
/// Maps (name, scope-set) → ResolvedBinding.
///
/// Used only during expansion and compilation — not at runtime.
/// The VM continues to use Module.Bindings for GVAR/GSET.
///
/// Resolution finds the most specific binding: the entry whose scope set
/// is a subset of the reference's scope set, with the largest scope count.
/// </summary>
public class BindingTable
{
    private readonly Dictionary<string, List<Entry>> entries = new();
    private readonly object lockObj = new();

    private struct Entry
    {
        public ScopeSet Scopes;
        public ResolvedBinding Binding;
    }

    /// <summary>
    /// Add or replace a binding in the table.
    /// Per sets-of-scopes, each (name, scope-set) pair maps to exactly one binding.
    /// If an entry with the same name and equal scope set exists, it is replaced.
    /// </summary>
    public void Add(string name, ScopeSet scopes, ResolvedBinding binding)
    {
        lock (lockObj)
        {
            if (!entries.TryGetValue(name, out var list))
            {
                list = new List<Entry>();
                entries[name] = list;
            }
            for (int i = 0; i < list.Count; i++)
            {
                if (list[i].Scopes.SetEquals(scopes))
                {
                    list[i] = new Entry { Scopes = scopes, Binding = binding };
                    return;
                }
            }
            list.Add(new Entry { Scopes = scopes, Binding = binding });
        }
    }

    /// <summary>
    /// Resolve a name with the given reference scope set.
    /// Finds all entries whose scope set is a subset of refScopes,
    /// then picks the one with the largest scope set (most specific).
    /// Returns null if no binding found.
    /// </summary>
    public ResolvedBinding? Resolve(string name, ScopeSet refScopes)
    {
        List<Entry>? list;
        lock (lockObj)
        {
            if (!entries.TryGetValue(name, out list))
                return null;
            // Snapshot the list to avoid holding lock during iteration
            list = new List<Entry>(list);
        }

        ResolvedBinding? best = null;
        int bestCount = -1;
        bool ambiguous = false;

        for (int i = 0; i < list.Count; i++)
        {
            var entry = list[i];
            if (entry.Scopes.IsSubsetOf(refScopes))
            {
                if (entry.Scopes.Count > bestCount)
                {
                    best = entry.Binding;
                    bestCount = entry.Scopes.Count;
                    ambiguous = false;
                }
                else if (entry.Scopes.Count == bestCount)
                {
                    ambiguous = true;
                }
            }
        }

        if (ambiguous)
            throw new SchemeError("ambiguous binding for ~a", name);

        return best;
    }

    /// <summary>
    /// Register core form bindings (if, lambda, let, etc.) with the given scope.
    /// Shared bindings ensure all modules use the same ResolvedBinding instance
    /// (and thus the same label) for each core form, so free-identifier=? works
    /// correctly across module boundaries.
    /// </summary>
    private readonly HashSet<int> registeredCoreFormScopes = new();
    private static readonly Dictionary<string, ResolvedBinding> sharedCoreFormBindings = new();

    public void RegisterCoreFormBindings(int moduleScope)
    {
        lock (lockObj)
        {
            if (registeredCoreFormScopes.Contains(moduleScope))
                return;
            registeredCoreFormScopes.Add(moduleScope);
        }

        var scopeSet = ScopeSet.Of(moduleScope);
        string[] coreFormNames = {
            "quote", "quasiquote", "if", "set!", "begin",
            "lambda", "define", "define-syntax",
            "let", "let*", "letrec", "letrec*",
            "let-syntax", "letrec-syntax", "cond-expand",
            "import", "%primitive", "define-library"
        };

        foreach (var name in coreFormNames)
        {
            ResolvedBinding binding;
            lock (sharedCoreFormBindings)
            {
                if (!sharedCoreFormBindings.TryGetValue(name, out binding!))
                {
                    binding = ResolvedBinding.MakeCoreForm(name);
                    sharedCoreFormBindings[name] = binding;
                }
            }
            Add(name, scopeSet, binding);
        }
    }
}
