using System.Collections.Generic;

namespace scheme;

public class PrimitiveDoImportSet : Primitive
{
    private Modules modules;

    public PrimitiveDoImportSet(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "%do-import-set";

    public override string Info() =>
        "Syntax: (%do-import-set import-spec)\n" +
        "Library: (scm core)\n" +
        "Description: Internal primitive that processes an R7RS import set (with only, except, prefix, rename transformers) and imports the resulting bindings into the current module.\n" +
        "Example:\n" +
        "  (%do-import-set '(scheme base))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var importResult = DoImportSet(pos, arguments[0]);
        var module = modules.GetCurrentModule();
        foreach (var kv in importResult.Bindings)
            module.ImportBinding(pos, kv.Key, kv.Value, importResult.Provenance[kv.Key]);
        return Value.T;
    }

    public ImportResult DoImportSet(SourcePos? pos, object importSpec)
    {
        if (Value.IsPair(importSpec))
        {
            var specPair = Value.AsPair(importSpec);
            var head = specPair.car as string;

            if (head == "only")
            {
                var inner = Value.AsPair(specPair.cdr).car;
                var src = DoImportSet(pos, inner);
                var result = new ImportResult();
                object syms = Value.AsPair(Value.AsPair(specPair.cdr).cdr);
                while (syms != Value.NIL)
                {
                    var symsPair = Value.AsPair(syms);
                    var sym = Value.AsSymbol(symsPair.car);
                    result.Bindings[sym] = src.Bindings[sym];
                    result.Provenance[sym] = src.Provenance[sym];
                    syms = symsPair.cdr;
                }
                return result;
            }
            else if (head == "except")
            {
                var inner = Value.AsPair(specPair.cdr).car;
                var src = DoImportSet(pos, inner);
                var excluded = new HashSet<string>();
                object excList = Value.AsPair(Value.AsPair(specPair.cdr).cdr);
                while (excList != Value.NIL)
                {
                    var excPair = Value.AsPair(excList);
                    excluded.Add(Value.AsSymbol(excPair.car));
                    excList = excPair.cdr;
                }
                var result = new ImportResult();
                foreach (var kv in src.Bindings)
                {
                    if (!excluded.Contains(kv.Key))
                    {
                        result.Bindings[kv.Key] = kv.Value;
                        result.Provenance[kv.Key] = src.Provenance[kv.Key];
                    }
                }
                return result;
            }
            else if (head == "prefix")
            {
                var inner = Value.AsPair(specPair.cdr).car;
                var pfx = Value.AsSymbol(Value.AsPair(Value.AsPair(specPair.cdr).cdr).car);
                var src = DoImportSet(pos, inner);
                var result = new ImportResult();
                foreach (var kv in src.Bindings)
                {
                    result.Bindings[pfx + kv.Key] = kv.Value;
                    result.Provenance[pfx + kv.Key] = src.Provenance[kv.Key];
                }
                return result;
            }
            else if (head == "rename")
            {
                var inner = Value.AsPair(specPair.cdr).car;
                var src = DoImportSet(pos, inner);
                var renames = new Dictionary<string, string>();
                object renameList = Value.AsPair(Value.AsPair(specPair.cdr).cdr);
                while (renameList != Value.NIL)
                {
                    var renamePair = Value.AsPair(renameList);
                    var pair = Value.AsPair(renamePair.car);
                    var oldName = Value.AsSymbol(pair.car);
                    var newName = Value.AsSymbol(Value.AsPair(pair.cdr).car);
                    renames[oldName] = newName;
                    renameList = renamePair.cdr;
                }
                var result = new ImportResult();
                foreach (var kv in src.Bindings)
                {
                    var destName = renames.TryGetValue(kv.Key, out var renamed) ? renamed : kv.Key;
                    result.Bindings[destName] = kv.Value;
                    result.Provenance[destName] = src.Provenance[kv.Key];
                }
                return result;
            }
        }

        // Base case: plain library name — load and return its exports.
        // We propagate Cells (not values) so importers share the exporter's
        // binding cells; `set!` in either module is visible in the other.
        new PrimitiveLoadModule(modules).Apply(pos, new object[] { importSpec });
        var plainModule = modules.GetModuleRequired(pos, Modules.AsModuleName(importSpec));
        var baseResult = new ImportResult();
        foreach (var kv in plainModule.Exports)
        {
            baseResult.Bindings[kv.Key] = kv.Value;
            baseResult.Provenance[kv.Key] = plainModule.Provenance.GetValueOrDefault(kv.Key, plainModule.Name);
        }
        return baseResult;
    }
}
