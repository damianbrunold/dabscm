package scheme.primitives;

import java.util.HashMap;
import java.util.HashSet;

import scheme.ImportResult;
import scheme.Modules;
import scheme.Pair;
import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;

public class PrimitiveDoImportSet extends Primitive {
    private Modules modules;

    public PrimitiveDoImportSet(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "%do-import-set";
    }

    @Override
    public String info() {
        return "Syntax: (%do-import-set import-spec)\n" +
               "Library: (scm core)\n" +
               "Description: Internal primitive that processes an R7RS import set (with only, except, prefix, rename transformers) and imports the resulting bindings into the current module.\n" +
               "Example:\n" +
               "  (%do-import-set '(scheme base))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var importResult = doImportSet(pos, arguments[0]);
        var module = modules.getCurrentModule();
        for (var kv : importResult.bindings.entrySet())
            module.importBinding(pos, kv.getKey(), kv.getValue(), importResult.provenance.get(kv.getKey()));
        return Value.T;
    }

    public ImportResult doImportSet(SourcePos pos, Object importSpec) {
        if (Value.isPair(importSpec)) {
            var specPair = Value.asPair(importSpec);
            var head = specPair.car instanceof String ? (String) specPair.car : null;

            if ("only".equals(head)) {
                var inner = Value.asPair(specPair.cdr).car;
                var src = doImportSet(pos, inner);
                var result = new ImportResult();
                Object syms = Value.asPair(Value.asPair(specPair.cdr).cdr);
                while (syms != Value.NIL) {
                    var symsPair = Value.asPair(syms);
                    var sym = Value.asSymbol(symsPair.car);
                    result.bindings.put(sym, src.bindings.get(sym));
                    result.provenance.put(sym, src.provenance.get(sym));
                    syms = symsPair.cdr;
                }
                return result;
            } else if ("except".equals(head)) {
                var inner = Value.asPair(specPair.cdr).car;
                var src = doImportSet(pos, inner);
                var excluded = new HashSet<String>();
                Object excList = Value.asPair(Value.asPair(specPair.cdr).cdr);
                while (excList != Value.NIL) {
                    var excPair = Value.asPair(excList);
                    excluded.add(Value.asSymbol(excPair.car));
                    excList = excPair.cdr;
                }
                var result = new ImportResult();
                for (var entry : src.bindings.entrySet()) {
                    if (!excluded.contains(entry.getKey())) {
                        result.bindings.put(entry.getKey(), entry.getValue());
                        result.provenance.put(entry.getKey(), src.provenance.get(entry.getKey()));
                    }
                }
                return result;
            } else if ("prefix".equals(head)) {
                var inner = Value.asPair(specPair.cdr).car;
                var pfx = Value.asSymbol(Value.asPair(Value.asPair(specPair.cdr).cdr).car);
                var src = doImportSet(pos, inner);
                var result = new ImportResult();
                for (var entry : src.bindings.entrySet()) {
                    result.bindings.put(pfx + entry.getKey(), entry.getValue());
                    result.provenance.put(pfx + entry.getKey(), src.provenance.get(entry.getKey()));
                }
                return result;
            } else if ("rename".equals(head)) {
                var inner = Value.asPair(specPair.cdr).car;
                var src = doImportSet(pos, inner);
                var renames = new HashMap<String, String>();
                Object renameList = Value.asPair(Value.asPair(specPair.cdr).cdr);
                while (renameList != Value.NIL) {
                    var renamePair = Value.asPair(renameList);
                    var pair = Value.asPair(renamePair.car);
                    var oldName = Value.asSymbol(pair.car);
                    var newName = Value.asSymbol(Value.asPair(pair.cdr).car);
                    renames.put(oldName, newName);
                    renameList = renamePair.cdr;
                }
                var result = new ImportResult();
                for (var entry : src.bindings.entrySet()) {
                    var destName = renames.getOrDefault(entry.getKey(), entry.getKey());
                    result.bindings.put(destName, entry.getValue());
                    result.provenance.put(destName, src.provenance.get(entry.getKey()));
                }
                return result;
            }
        }

        // Base case: plain library name — load and return its exports
        new PrimitiveLoadModule(modules).apply(pos, new Object[] { importSpec });
        var plainModule = modules.getModuleRequired(pos, Modules.asModuleName(importSpec));
        var baseResult = new ImportResult();
        for (var kv : plainModule.exports.entrySet()) {
            baseResult.bindings.put(kv.getKey(), kv.getValue());
            String origin = plainModule.provenance.get(kv.getKey());
            baseResult.provenance.put(kv.getKey(), origin != null ? origin : plainModule.getName());
        }
        return baseResult;
    }
}
