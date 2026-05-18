package scheme;

import java.util.HashMap;
import java.util.Map;

public class Module {
    private String name;
    private Object decl;
    private boolean autoExport = false;

    public Map<String, Cell> bindings = new HashMap<>();
    public Map<String, Cell> exports = new HashMap<>();
    public Map<String, String> provenance = new HashMap<>();

    public Module(String name) {
        this.name = name;
        this.decl = Pair.list((Object[]) name.split(" "));
    }

    public Module(String name, boolean autoExport) {
        this.name = name;
        this.decl = Pair.list((Object[]) name.split(" "));
        this.autoExport = autoExport;
    }

    public String getName() {
        return name;
    }

    public Object getDecl() {
        return decl;
    }

    public boolean isBound(String symbol) {
        return bindings.containsKey(Value.intern(symbol));
    }

    public Object resolve(SourcePos pos, String symbol) {
        Cell cell = bindings.get(Value.intern(symbol));
        if (cell == null) {
            throw new SchemeError(pos, name + ": ~a is not bound", symbol);
        }
        return cell.value;
    }

    public Object resolve(String symbol) {
        return resolve(null, symbol);
    }

    public Cell resolveCell(String symbol) {
        return bindings.get(Value.intern(symbol));
    }

    public void bind(String symbol, Object value) {
        bind(symbol, value, name);
    }

    public void bind(String symbol, Object value, String origin) {
        String interned = Value.intern(symbol);
        Cell existing = bindings.get(interned);
        if (existing != null) {
            existing.value = value;
        } else {
            bindings.put(interned, new Cell(value));
        }
        provenance.put(interned, origin);
        if (autoExport) {
            exports.put(interned, bindings.get(interned));
        }
    }

    public void importBinding(SourcePos pos, String symbol, Cell cell, String origin) {
        String interned = Value.intern(symbol);
        String existingOrigin = provenance.get(interned);
        if (existingOrigin != null && !existingOrigin.equals(origin)) {
            Cell existingCell = bindings.get(interned);
            if (existingCell != null &&
                (existingCell == cell || existingCell.value == cell.value)) {
                // Same cell, or two cells wrapping the same value
                // (e.g. two libraries each binding the same primitive) —
                // no conflict
            } else if ("scm core".equals(existingOrigin) || "scm core".equals(origin)) {
                // scm core provides bootstrap versions that can be superseded
            } else if (Scheme.strictImports) {
                throw new SchemeError(pos,
                    "import: symbol '~a' is imported from both '~a' and '~a'",
                    symbol, existingOrigin, origin);
            }
        }
        bindings.put(interned, cell);
        provenance.put(interned, origin);
    }

    public void export(String symbol) {
        String interned = Value.intern(symbol);
        Cell cell = bindings.get(interned);
        if (cell == null) {
            throw new SchemeError("library '~a': cannot export '~a': not defined or imported", name, symbol);
        }
        exports.put(interned, cell);
    }

    public void export(String src, String dest) {
        String internedSrc = Value.intern(src);
        Cell cell = bindings.get(internedSrc);
        if (cell == null) {
            throw new SchemeError("library '~a': cannot export '~a': not defined or imported", name, src);
        }
        exports.put(Value.intern(dest), cell);
    }

    @Override
    public Module clone() {
        Module c = new Module(name);
        c.bindings.putAll(bindings);
        c.exports.putAll(exports);
        c.provenance.putAll(provenance);
        return c;
    }

}
