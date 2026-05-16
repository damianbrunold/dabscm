package scheme.primitives;

import scheme.Modules;
import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;

public class PrimitiveModuleExportBindings extends Primitive {
    private Modules modules;

    public PrimitiveModuleExportBindings(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "%module-export-bindings";
    }

    @Override
    public String info() {
        return "Syntax: (%module-export-bindings module-name symbol ...)\n" +
               "Library: (scm core)\n" +
               "Description: Internal primitive. Marks the given symbols as exported from the named module. Each symbol must already be bound in the module.\n" +
               "Example:\n" +
               "  (%module-export-bindings '(my lib) 'foo 'bar)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, -1);
        var moduleName = Modules.asModuleName(arguments[0]);
        var module = modules.getModule(moduleName);
        if (module != null) {
            for (var i = 1; i < arguments.length; i++) {
                var symbol = Value.asSymbol(arguments[i]);
                var binding = module.bindings.get(symbol);
                if (binding == null)
                    throw new SchemeError(pos, "library '~s': cannot export '~s': not defined or imported", moduleName, symbol);
                module.exports.put(symbol, binding);
            }
            return Value.T;
        }
        return Value.F;
    }
}
