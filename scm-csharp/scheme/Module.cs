namespace scheme;

public class Module
{
    public string Name { get; }
    public object Decl { get; }
    public Dictionary<string, Cell> Bindings = new();
    public Dictionary<string, Cell> Exports = new();
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
        if (!Bindings.TryGetValue(symbol, out var cell))
            throw new SchemeError(pos, Name + ": ~a is not bound", symbol);
        return cell.value;
    }

    public Cell? ResolveCell(string symbol)
    {
        Bindings.TryGetValue(symbol, out var cell);
        return cell;
    }

    public void Bind(string symbol, object value)
    {
        Bind(symbol, value, Name);
    }

    public void Bind(string symbol, object value, string origin)
    {
        if (Bindings.TryGetValue(symbol, out var existing))
        {
            existing.value = value;
        }
        else
        {
            Bindings[symbol] = new Cell(value);
        }
        Provenance[symbol] = origin;
        if (autoExport)
        {
            Exports[symbol] = Bindings[symbol];
        }
    }

    public void ImportBinding(SourcePos? pos, string symbol, Cell cell, string origin)
    {
        if (Provenance.TryGetValue(symbol, out var existingOrigin))
        {
            if (existingOrigin != origin)
            {
                if (Bindings.TryGetValue(symbol, out var existingCell) &&
                    (ReferenceEquals(existingCell, cell) ||
                     ReferenceEquals(existingCell.value, cell.value)))
                {
                    // Same cell, or two cells wrapping the same value
                    // (e.g. two libraries each binding the same primitive) —
                    // no conflict
                }
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
        Bindings[symbol] = cell;
        Provenance[symbol] = origin;
    }

    public void Export(string symbol)
    {
        if (!Bindings.TryGetValue(symbol, out var cell))
        {
            throw new SchemeError("library '~a': cannot export '~a': not defined or imported", Name, symbol);
        }
        Exports[symbol] = cell;
    }

    public void Export(string src, string dest)
    {
        if (!Bindings.TryGetValue(src, out var cell))
        {
            throw new SchemeError("library '~a': cannot export '~a': not defined or imported", Name, src);
        }
        Exports[dest] = cell;
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
