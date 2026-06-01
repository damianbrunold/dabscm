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
        // Mutate the existing cell in place only when redefining a binding
        // this module already owns (same provenance). When a define shadows
        // a name imported from another module, allocate a fresh cell so we
        // don't clobber the source module's (shared) cell — otherwise e.g.
        // (scm fs-find) defining its own `find` would overwrite the `find`
        // it imported from (srfi 1), corrupting it for every other importer.
        if (Bindings.TryGetValue(symbol, out var existing)
            && Provenance.TryGetValue(symbol, out var existingOrigin)
            && existingOrigin == origin)
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

    // Clone with a cell-identity map so cross-module cell aliasing
    // (e.g. a binding shared between an exporter and its importers) is
    // preserved in the clone: every old cell maps to one new cell,
    // looked up via `cellMap`. Used by Modules.DeepClone (which builds
    // one map across all modules) for TakeSnapshot / RestoreFromSnapshot.
    // The new cell wraps the current value, so mutations after the
    // snapshot don't leak into the clone.
    public Module Clone(Dictionary<Cell, Cell> cellMap)
    {
        var clone = new Module(Name, false);
        foreach (var kv in Bindings)
            clone.Bindings[kv.Key] = MapCell(kv.Value, cellMap);
        foreach (var kv in Exports)
            clone.Exports[kv.Key] = MapCell(kv.Value, cellMap);
        foreach (var kv in Provenance) clone.Provenance[kv.Key] = kv.Value;
        return clone;
    }

    private static Cell MapCell(Cell old, Dictionary<Cell, Cell> cellMap)
    {
        if (!cellMap.TryGetValue(old, out var fresh))
        {
            fresh = new Cell(old.value);
            cellMap[old] = fresh;
        }
        return fresh;
    }
}
