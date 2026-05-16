package scheme;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Thread-safe binding table for the sets-of-scopes macro hygiene model.
 * Maps (name, scope-set) → ResolvedBinding.
 *
 * Used only during expansion and compilation — not at runtime.
 * The VM continues to use Module.bindings for GVAR/GSET.
 *
 * Resolution finds the most specific binding: the entry whose scope set
 * is a subset of the reference's scope set, with the largest scope count.
 */
public class BindingTable {
    private final Map<String, List<Entry>> entries = new HashMap<>();
    private final Object lockObj = new Object();

    private static class Entry {
        final ScopeSet scopes;
        final ResolvedBinding binding;

        Entry(ScopeSet scopes, ResolvedBinding binding) {
            this.scopes = scopes;
            this.binding = binding;
        }
    }

    /**
     * Add or replace a binding in the table.
     * Per sets-of-scopes, each (name, scope-set) pair maps to exactly one binding.
     * If an entry with the same name and equal scope set exists, it is replaced.
     */
    public void add(String name, ScopeSet scopes, ResolvedBinding binding) {
        synchronized (lockObj) {
            List<Entry> list = entries.get(name);
            if (list == null) {
                list = new ArrayList<>();
                entries.put(name, list);
            }
            for (int i = 0; i < list.size(); i++) {
                if (list.get(i).scopes.equals(scopes)) {
                    list.set(i, new Entry(scopes, binding));
                    return;
                }
            }
            list.add(new Entry(scopes, binding));
        }
    }

    /**
     * Resolve a name with the given reference scope set.
     * Finds all entries whose scope set is a subset of refScopes,
     * then picks the one with the largest scope set (most specific).
     * Returns null if no binding found.
     */
    public ResolvedBinding resolve(String name, ScopeSet refScopes) {
        List<Entry> list;
        synchronized (lockObj) {
            List<Entry> orig = entries.get(name);
            if (orig == null) return null;
            // Snapshot the list to avoid holding lock during iteration
            list = new ArrayList<>(orig);
        }

        ResolvedBinding best = null;
        int bestCount = -1;
        boolean ambiguous = false;

        for (int i = 0; i < list.size(); i++) {
            Entry entry = list.get(i);
            if (entry.scopes.isSubsetOf(refScopes)) {
                if (entry.scopes.count() > bestCount) {
                    best = entry.binding;
                    bestCount = entry.scopes.count();
                    ambiguous = false;
                } else if (entry.scopes.count() == bestCount) {
                    ambiguous = true;
                }
            }
        }

        if (ambiguous)
            throw new SchemeError("ambiguous binding for ~a", name);

        return best;
    }

    private final Set<Integer> registeredCoreFormScopes = new HashSet<>();
    private static final Map<String, ResolvedBinding> sharedCoreFormBindings = new HashMap<>();

    /**
     * Register core form bindings (if, lambda, let, etc.) with the given scope.
     * Shared bindings ensure all modules use the same ResolvedBinding instance
     * (and thus the same label) for each core form, so free-identifier=? works
     * correctly across module boundaries.
     */
    public void registerCoreFormBindings(int moduleScope) {
        synchronized (lockObj) {
            if (registeredCoreFormScopes.contains(moduleScope))
                return;
            registeredCoreFormScopes.add(moduleScope);
        }

        ScopeSet scopeSet = ScopeSet.of(moduleScope);
        String[] coreFormNames = {
            "quote", "quasiquote", "if", "set!", "begin",
            "lambda", "define", "define-syntax",
            "let", "let*", "letrec", "letrec*",
            "let-syntax", "letrec-syntax", "cond-expand",
            "import", "%primitive", "define-library"
        };

        for (String name : coreFormNames) {
            ResolvedBinding binding;
            synchronized (sharedCoreFormBindings) {
                binding = sharedCoreFormBindings.get(name);
                if (binding == null) {
                    binding = ResolvedBinding.makeCoreForm(name);
                    sharedCoreFormBindings.put(name, binding);
                }
            }
            add(name, scopeSet, binding);
        }
    }
}
