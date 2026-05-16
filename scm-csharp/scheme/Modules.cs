using System.Text;

namespace scheme;

public class Modules
{
    private Dictionary<string, Module> modules = new();
    private Dictionary<string, string> moduleLoadPaths = new();
    private HashSet<string> loadingModules = new();
    private Module currentModule = null!;
    private Modules? snapshot;

    public Primitives primitives = null!;
    public IEvaluator? Evaluator { get; set; }

    private readonly BindingTable bindingTable;
    private readonly Dictionary<string, int> moduleScopes;

    public BindingTable BindingTable => bindingTable;

    public int GetModuleScope(string moduleName)
    {
        if (!moduleScopes.TryGetValue(moduleName, out int scope))
        {
            scope = ScopeSet.FreshScope();
            moduleScopes[moduleName] = scope;
        }
        return scope;
    }

    public int GetCurrentModuleScope()
        => GetModuleScope(GetCurrentModule().Name);

    public bool IsLoading(string name) => loadingModules.Contains(name);
    public void MarkLoading(string name) => loadingModules.Add(name);
    public void UnmarkLoading(string name) => loadingModules.Remove(name);
    
    public Modules()
    {
        this.bindingTable = new BindingTable();
        this.moduleScopes = new Dictionary<string, int>();
        var scm_core = new Module("scm core");
        this.modules["scm core"] = scm_core;
        this.currentModule = scm_core;

        this.primitives = new Primitives();
        this.primitives.Init(this);

        // Bootstrap: only bind primitives needed for library.scm to load
        scm_core.Bind("%module-export-bindings", primitives.GetPrimitive("%module-export-bindings"));
        scm_core.Bind("%load-module", primitives.GetPrimitive("%load-module"));
        scm_core.Bind("read", primitives.GetPrimitive("read"));

        // Register core form markers so they can be exported from (scm core)
        string[] coreFormKeywords = {
            "quote", "quasiquote", "if", "set!", "begin",
            "lambda", "define", "define-syntax",
            "let", "let*", "letrec", "letrec*",
            "let-syntax", "letrec-syntax", "cond-expand",
            "%primitive", "import", "define-library"
        };
        foreach (var name in coreFormKeywords)
            scm_core.Bind(name, new CoreFormMarker(name));

        // Register bootstrap primitives in the binding table
        int coreScope = GetModuleScope("scm core");
        var coreScopeSet = ScopeSet.Of(coreScope);
        foreach (string name in new[] { "%module-export-bindings", "%load-module", "read" })
        {
            bindingTable.Add(name, coreScopeSet,
                new ResolvedBinding(ResolvedBinding.Kind.Global,
                    "scm core:" + name, "scm core", name, name, null));
        }
    }

    public Modules(Modules src, Module currentModule)
    {
        this.bindingTable = src.bindingTable;
        this.moduleScopes = src.moduleScopes;
        foreach (var kv in src.modules)
        {
            this.modules[kv.Key] = kv.Value;
        }
        foreach (var kv in src.moduleLoadPaths)
        {
            this.moduleLoadPaths[kv.Key] = kv.Value;
        }
        this.currentModule = currentModule;
        this.primitives = src.primitives;
    }

    private Modules(bool _skipInit)
    {
        this.bindingTable = new BindingTable();
        this.moduleScopes = new Dictionary<string, int>();
    }

    public Modules DeepClone()
    {
        var clone = new Modules(false);
        clone.primitives = this.primitives;
        foreach (var kv in modules)
            clone.modules[kv.Key] = kv.Value.Clone();
        foreach (var kv in moduleLoadPaths)
            clone.moduleLoadPaths[kv.Key] = kv.Value;
        clone.currentModule = clone.modules[currentModule.Name];
        return clone;
    }

    public Module GetCurrentModule() => currentModule;

    public Module CreateModule(string name)
    {
        var module = new Module(name);
        modules[name] = module;
        UpdateModuleVar();
        return module;
    }
    
    public Module SetCurrentModule(string moduleName)
    {
        if (!modules.TryGetValue(moduleName, out var module))
        {
            module = CreateModule(moduleName);
        }
        currentModule = module;
        return currentModule;
    }

    public bool HasModule(string name) => modules.ContainsKey(name);

    public Module? GetModule(string name) => modules.GetValueOrDefault(name);

    public Module GetModuleRequired(SourcePos? pos, string name)
    {
        var result = modules.GetValueOrDefault(name);
        if (result == null)
        {
            throw new SchemeError(pos, "Modules: " + name + " not available");
        }
        return result;
    }

    public void AddModule(Module module)
    {
        modules[module.Name] = module;
    }

    public void SetModuleLoadPath(string moduleName, string dirPath)
    {
        moduleLoadPaths[moduleName] = dirPath;
    }

    public string? GetModuleLoadPath(string moduleName)
    {
        return moduleLoadPaths.GetValueOrDefault(moduleName);
    }

    public void ResetModules()
    {
        var toRemove = modules.Keys.Where(k => !k.StartsWith("scheme") && !k.StartsWith("scm") && !k.StartsWith("srfi")).ToList();
        foreach (var k in toRemove) modules.Remove(k);
    }

    public void TakeSnapshot()
    {
        snapshot = DeepClone();
    }

    public bool HasSnapshot() => snapshot != null;

    public void RestoreFromSnapshot()
    {
        if (snapshot == null) return;
        modules.Clear();
        foreach (var kv in snapshot.modules)
            modules[kv.Key] = kv.Value.Clone();
        moduleLoadPaths.Clear();
        foreach (var kv in snapshot.moduleLoadPaths)
            moduleLoadPaths[kv.Key] = kv.Value;
        currentModule = modules[snapshot.currentModule.Name];
        loadingModules.Clear();
    }

    public void UpdateModuleVar()
    {
        var scm_core = GetModuleRequired(null, "scm core");
        List<object> entries = new();
        foreach (var module in modules.Values.OrderBy(m => m.Name).ToArray())
        {
            entries.Add(module.Decl);
        }
        var list = Pair.List(entries.ToArray());
        scm_core.Bind("*modules*", list);
    }

    public static string AsModuleName(object value)
    {
        if (Value.IsSymbol(value)) return Value.AsSymbol(value);
        if (Value.IsPair(value))
        {
            // SRFI 97: (srfi :N ...) → "srfi N"
            var p = Value.AsPair(value);
            if (Value.IsSymbol(p.car) && Value.AsSymbol(p.car) == "srfi" && Value.IsPair(p.cdr))
            {
                var second = Value.AsPair(p.cdr).car;
                if (Value.IsSymbol(second))
                {
                    var sym = Value.AsSymbol(second);
                    if (sym.StartsWith(":") && sym.Length > 1 && sym[1..].All(char.IsDigit))
                        return "srfi " + sym[1..];
                    if (sym.StartsWith("srfi-") && sym.Length > 5 && sym[5..].All(char.IsDigit))
                        return "srfi " + sym[5..];
                }
            }

            var sb = new StringBuilder();
            object cur = Value.AsPair(value);
            while (cur != Value.NIL)
            {
                var curPair = Value.AsPair(cur);
                if (Value.IsSymbol(curPair.car)) sb.Append(Value.AsSymbol(curPair.car));
                else if (Value.IsInteger(curPair.car)) sb.Append(curPair.car);
                else sb.Append(Value.DisplayRep(curPair.car));
                sb.Append(' ');
                cur = curPair.cdr;
            }
            return sb.ToString().TrimEnd();
        }
        return new string(Value.AsString(value));
    }
}
