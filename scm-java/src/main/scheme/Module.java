package scheme;

import java.util.HashMap;
import java.util.Map;

public class Module {
    private String name;
    private Object decl;
    private boolean autoExport = false;

    public Map<String, Object> bindings = new HashMap<>();
    public Map<String, Object> exports = new HashMap<>();
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
        Object result = bindings.get(Value.intern(symbol));
        if (result == null) {
            throw new SchemeError(pos, name + ": ~a is not bound", symbol);
        }
        return result;
    }

    public Object resolve(String symbol) {
        return resolve(null, symbol);
    }

    public void bind(String symbol, Object value) {
        bind(symbol, value, name);
    }

    public void bind(String symbol, Object value, String origin) {
        String interned = Value.intern(symbol);
        bindings.put(interned, value);
        provenance.put(interned, origin);
        if (autoExport) {
            exports.put(interned, value);
        }
    }

    public void importBinding(SourcePos pos, String symbol, Object value, String origin) {
        String interned = Value.intern(symbol);
        String existingOrigin = provenance.get(interned);
        if (existingOrigin != null && !existingOrigin.equals(origin)) {
            Object existingValue = bindings.get(interned);
            if (existingValue != null && existingValue == value) {
                // Same object — no conflict
            } else if ("scm core".equals(existingOrigin) || "scm core".equals(origin)) {
                // scm core provides bootstrap versions that can be superseded
            } else if (Scheme.strictImports) {
                throw new SchemeError(pos,
                    "import: symbol '~a' is imported from both '~a' and '~a'",
                    symbol, existingOrigin, origin);
            }
        }
        bindings.put(interned, value);
        provenance.put(interned, origin);
    }

    public void export(String symbol) {
        String interned = Value.intern(symbol);
        if (!bindings.containsKey(interned)) {
            throw new SchemeError("library '~a': cannot export '~a': not defined or imported", name, symbol);
        }
        exports.put(interned, bindings.get(interned));
    }

    public void export(String src, String dest) {
        String internedSrc = Value.intern(src);
        if (!bindings.containsKey(internedSrc)) {
            throw new SchemeError("library '~a': cannot export '~a': not defined or imported", name, src);
        }
        exports.put(Value.intern(dest), bindings.get(internedSrc));
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
