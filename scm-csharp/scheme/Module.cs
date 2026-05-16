namespace scheme;

public class Module
{
    public string Name { get; }
    public object Decl { get; }
    public Dictionary<string, object> Bindings = new();
    public Dictionary<string, object> Exports = new();
    public Dictionary<string, string> Provenance = new();

    private bool autoExport = false;

    public Module(string name)
    {
        Name = name;
        Decl = Pair.List(name.Split(' ').Select(s => (object)Value.Intern(s)).ToArray());
    }

    public Module(string name, bool autoExport)
    {
        Name = name;
        Decl = Pair.List(name.Split(' ').Select(s => (object)Value.Intern(s)).ToArray());
        this.autoExport = autoExport;
    }

    public bool IsBound(string symbol) => Bindings.ContainsKey(symbol);

    public object Resolve(SourcePos? pos, string symbol)
    {
        return Bindings.GetValueOrDefault(symbol)
            ?? throw new SchemeError(pos, Name + ": ~a is not bound", symbol);
    }

    public void Bind(string symbol, object value)
    {
        Bind(symbol, value, Name);
    }

    public void Bind(string symbol, object value, string origin)
    {
        Bindings[symbol] = value;
        Provenance[symbol] = origin;
        if (autoExport)
        {
            Exports[symbol] = value;
        }
    }

    public void ImportBinding(SourcePos? pos, string symbol, object value, string origin)
    {
        if (Provenance.TryGetValue(symbol, out var existingOrigin))
        {
            if (existingOrigin != origin)
            {
                // Allow if both bindings resolve to the same value
                if (Bindings.TryGetValue(symbol, out var existingValue) &&
                    ReferenceEquals(existingValue, value))
                {
                    // Same object — no conflict
                }
                // Allow scm core bootstrap bindings to be overridden in either direction
                else if (existingOrigin == "scm core" || origin == "scm core")
                {
                    // scm core provides bootstrap versions that can be superseded
                }
                else if (Scheme.StrictImports)
                {
                    throw new SchemeError(pos,
                        "import: symbol '~a' is imported from both '~a' and '~a'",
                        symbol, existingOrigin, origin);
                }
            }
        }
        Bindings[symbol] = value;
        Provenance[symbol] = origin;
    }
    
    public void Export(string symbol)
    {
        if (!Bindings.TryGetValue(symbol, out var binding))
        {
            throw new SchemeError("library '~a': cannot export '~a': not defined or imported", Name, symbol);
        }
        Exports[symbol] = binding;
    }

    public void Export(string src, string dest)
    {
        if (!Bindings.TryGetValue(src, out var binding))
        {
            throw new SchemeError("library '~a': cannot export '~a': not defined or imported", Name, src);
        }
        Exports[dest] = binding;
    }

    public Module Clone()
    {
        var clone = new Module(Name, false);
        foreach (var kv in Bindings) clone.Bindings[kv.Key] = kv.Value;
        foreach (var kv in Exports)  clone.Exports[kv.Key]  = kv.Value;
        foreach (var kv in Provenance) clone.Provenance[kv.Key] = kv.Value;
        return clone;
    }
}
