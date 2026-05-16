package scheme.primitives;

import scheme.Modules;
import scheme.Primitive;
import scheme.SourcePos;
import scheme.Value;

public class PrimitiveModuleImportBindings extends Primitive {
    private Modules modules;

    public PrimitiveModuleImportBindings(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "%module-import-bindings";
    }

    @Override
    public String info() {
        return "Syntax: (%module-import-bindings module-dest module-src symbol ...)\n" +
               "Library: (scm core)\n" +
               "Description: Internal primitive. Imports the given symbols from module-src's exports into module-dest's bindings. A symbol may be a (old-name new-name) pair for renaming.\n" +
               "Example:\n" +
               "  (%module-import-bindings '(my lib) '(scheme base) 'cons 'car 'cdr)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, -1);
        var module_dest = modules.getModule(Modules.asModuleName(arguments[0]));
        var module_src = modules.getModule(Modules.asModuleName(arguments[1]));
        if (module_dest != null && module_src != null) {
            for (var i = 2; i < arguments.length; i++) {
                String symbol;
                String rename;
                if (Value.isPair(arguments[i])) {
                    symbol = Value.asSymbol(Value.asPair(arguments[i]).car);
                    rename = Value.asSymbol(Value.asPair(Value.asPair(arguments[i]).cdr).car);
                } else {
                    symbol = Value.asSymbol(arguments[i]);
                    rename = symbol;
                }
                var value = module_src.exports.get(symbol);
                String origin = module_src.provenance.get(symbol);
                if (origin == null) origin = module_src.getName();
                module_dest.importBinding(pos, rename, value, origin);
            }
            return Value.T;
        }
        return Value.F;
    }
}
