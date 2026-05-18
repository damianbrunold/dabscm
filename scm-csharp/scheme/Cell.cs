namespace scheme;

// One-field mutable box holding a binding's current value. Sharing a Cell
// across module dicts (e.g. between an exporter and its importers, or
// between threads after the DeepClone removal) is how `set!` becomes
// visible everywhere the binding is reachable. See
// notes/threading-shared-bindings.md.
public sealed class Cell
{
    public object value;
    public Cell(object value) { this.value = value; }
}
