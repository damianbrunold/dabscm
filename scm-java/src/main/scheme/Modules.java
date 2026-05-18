package scheme;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class Modules {
    private HashMap<String, Module> modules = new HashMap<>();
    private HashMap<String, String> moduleLoadPaths = new HashMap<>();
    // currentModule and loadingModules are per-thread so that, once the
    // bindings map is shared across threads (step 3), threads can have
    // independent (module ...)/import state without racing. See
    // notes/threading-shared-bindings.md. The Default field is what
    // newly-arriving threads (i.e. threads that haven't set their own
    // value yet) see — established at construction / deepClone time.
    private final ThreadLocal<Module> currentModuleTLS = new ThreadLocal<>();
    private Module currentModuleDefault;
    private final ThreadLocal<Set<String>> loadingModules =
        ThreadLocal.withInitial(HashSet::new);
    private Modules snapshot;

    // Serializes library loading. Library load mutates `modules`,
    // `moduleLoadPaths`, and the per-module bindings dicts (via bind/
    // importBinding). Now that Modules is shared across threads, two
    // threads importing the same library concurrently would race on
    // these mutations. The lock is reentrant (synchronized) so nested
    // %load-module calls during transitive imports are fine. See
    // notes/threading-shared-bindings.md.
    public final Object loadLock = new Object();

    public Primitives primitives;
    public IEvaluator evaluator;

    private BindingTable bindingTable;
    private HashMap<String, Integer> moduleScopes;

    public BindingTable getBindingTable() { return bindingTable; }

    public int getModuleScope(String moduleName) {
        Integer scope = moduleScopes.get(moduleName);
        if (scope == null) {
            scope = ScopeSet.freshScope();
            moduleScopes.put(moduleName, scope);
        }
        return scope;
    }

    public int getCurrentModuleScope() {
        return getModuleScope(getCurrentModule().getName());
    }

    public boolean isLoading(String name) { return loadingModules.get().contains(name); }
    public void markLoading(String name) { loadingModules.get().add(name); }
    public void unmarkLoading(String name) { loadingModules.get().remove(name); }

    public Modules() {
        this.bindingTable = new BindingTable();
        this.moduleScopes = new HashMap<>();
        var scm_core = new Module("scm core");
        this.modules.put("scm core", scm_core);
        this.currentModuleDefault = scm_core;
        this.currentModuleTLS.set(scm_core);

        this.primitives = new Primitives();
        this.primitives.init(this);

        // Bootstrap: only bind primitives needed for library.scm to load
        scm_core.bind("%module-export-bindings", primitives.getPrimitive("%module-export-bindings"));
        scm_core.bind("%load-module", primitives.getPrimitive("%load-module"));
        scm_core.bind("read", primitives.getPrimitive("read"));

        // Register core form markers so they can be exported from (scm core)
        String[] coreFormKeywords = {
            "quote", "quasiquote", "if", "set!", "begin",
            "lambda", "define", "define-syntax",
            "let", "let*", "letrec", "letrec*",
            "let-syntax", "letrec-syntax", "cond-expand",
            "%primitive", "import", "define-library"
        };
        for (String cfName : coreFormKeywords)
            scm_core.bind(cfName, new CoreFormMarker(cfName));

        // Register bootstrap primitives in the binding table
        int coreScope = getModuleScope("scm core");
        ScopeSet coreScopeSet = ScopeSet.of(coreScope);
        for (String name : new String[] { "%module-export-bindings", "%load-module", "read" }) {
            bindingTable.add(name, coreScopeSet,
                new ResolvedBinding(ResolvedBinding.Kind.GLOBAL,
                    "scm core:" + name, "scm core", name, name, null));
        }
    }

    public Modules(Modules src, Module currentModule) {
        this.bindingTable = src.bindingTable;
        this.moduleScopes = src.moduleScopes;
        for (var symbol : src.modules.keySet()) {
            modules.put(symbol, src.modules.get(symbol));
        }
        for (var entry : src.moduleLoadPaths.entrySet()) {
            moduleLoadPaths.put(entry.getKey(), entry.getValue());
        }
        this.currentModuleDefault = currentModule;
        this.currentModuleTLS.set(currentModule);
        this.primitives = src.primitives;
    }

    private Modules(boolean _skipInit) {
        this.bindingTable = new BindingTable();
        this.moduleScopes = new HashMap<>();
    }

    public Modules deepClone() {
        Modules clone = new Modules(false);
        clone.primitives = this.primitives;
        for (var kv : modules.entrySet())
            clone.modules.put(kv.getKey(), kv.getValue().clone());
        for (var kv : moduleLoadPaths.entrySet())
            clone.moduleLoadPaths.put(kv.getKey(), kv.getValue());
        Module parentCurrent = getCurrentModule();
        Module clonedCurrent = clone.modules.get(parentCurrent.getName());
        clone.currentModuleDefault = clonedCurrent;
        clone.currentModuleTLS.set(clonedCurrent);
        return clone;
    }

    public Module getCurrentModule() {
        Module m = currentModuleTLS.get();
        return m != null ? m : currentModuleDefault;
    }

    public Module createModule(String name) {
        var module = new Module(name);
        this.modules.put(name, module);
        updateModuleVar();
        return module;
    }
    
    public Module setCurrentModule(String moduleName) {
        var module = this.modules.get(moduleName);
        if (module == null) {
            module = createModule(moduleName);
        }
        this.currentModuleTLS.set(module);
        return module;
    }

    public boolean hasModule(String name) {
        return modules.containsKey(name);
    }

    public Module getModule(String name) {
        return modules.get(name);
    }

    public Module getModuleRequired(SourcePos pos, String name) {
        var result = modules.get(name);
        if (result == null) {
            throw new SchemeError(pos, "Modules: " + name + " not available");
        }
        return result;
    }

    public void addModule(Module module) {
        modules.put(module.getName(), module);
    }

    public void setModuleLoadPath(String moduleName, String dirPath) {
        moduleLoadPaths.put(moduleName, dirPath);
    }

    public String getModuleLoadPath(String moduleName) {
        return moduleLoadPaths.get(moduleName);
    }

    public void resetModules() {
        HashMap<String, Module> newModules = new HashMap<>();
        for (var moduleName : modules.keySet()) {
            if (moduleName.startsWith("scheme") || moduleName.startsWith("scm") || moduleName.startsWith("srfi")) {
                newModules.put(moduleName, modules.get(moduleName));
            }
        }
        modules.clear();
        modules = newModules;
    }

    public void takeSnapshot() {
        snapshot = deepClone();
    }

    public boolean hasSnapshot() {
        return snapshot != null;
    }

    public void restoreFromSnapshot() {
        if (snapshot == null) return;
        modules.clear();
        for (var kv : snapshot.modules.entrySet())
            modules.put(kv.getKey(), kv.getValue().clone());
        moduleLoadPaths.clear();
        moduleLoadPaths.putAll(snapshot.moduleLoadPaths);
        Module restored = modules.get(snapshot.currentModuleDefault.getName());
        currentModuleDefault = restored;
        currentModuleTLS.set(restored);
        loadingModules.get().clear();
    }

    public void updateModuleVar() {
        var scm_core = getModuleRequired(null, "scm core");
        List<Object> entries = new ArrayList<>();
        List<String> names = new ArrayList<>(modules.keySet());
        Collections.sort(names);
        for (var name : names) {
            entries.add(modules.get(name).getDecl());
        }
        var list = Pair.list(entries.toArray());
        scm_core.bind("*modules*", list);
    }

    public static String asModuleName(Object value) {
        if (Value.isSymbol(value)) {
            return Value.asSymbol(value);
        } else if (Value.isPair(value)) {
            // SRFI 97: (srfi :N ...) → "srfi N"
            var p = Value.asPair(value);
            if (Value.isSymbol(p.car) && "srfi".equals(Value.asSymbol(p.car)) && Value.isPair(p.cdr)) {
                var second = Value.asPair(p.cdr).car;
                if (Value.isSymbol(second)) {
                    var sym = Value.asSymbol(second);
                    if (sym.startsWith(":") && sym.length() > 1 && sym.substring(1).chars().allMatch(Character::isDigit))
                        return "srfi " + sym.substring(1);
                    if (sym.startsWith("srfi-") && sym.length() > 5 && sym.substring(5).chars().allMatch(Character::isDigit))
                        return "srfi " + sym.substring(5);
                }
            }
            var builder = new StringBuilder();
            Object current = Value.asPair(value);
            while (current != Value.NIL) {
                var curPair = Value.asPair(current);
                if (Value.isSymbol(curPair.car)) {
                    builder.append(Value.asSymbol(curPair.car));
                } else if (Value.isInteger(curPair.car)) {
                    builder.append(curPair.car);
                } else {
                    builder.append(Value.displayRep(curPair.car));
                }
                builder.append(" ");
                current = curPair.cdr;
            }
            return builder.toString().trim();
        } else {
            return new String(Value.asString(value));
        }
    }
}
