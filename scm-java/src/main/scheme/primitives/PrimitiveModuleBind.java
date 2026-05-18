package scheme.primitives;

import scheme.Modules;
import scheme.Primitive;
import scheme.SourcePos;
import scheme.Value;

public class PrimitiveModuleBind extends Primitive {
    private Modules modules;

    public PrimitiveModuleBind(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "%module-bind";
    }

    @Override
    public String info() {
        return "Syntax: (%module-bind module-name symbol value)\n" +
               "Library: (scm core)\n" +
               "Description: Binds or rebinds symbol to value in the named module, bypassing import checks. If the symbol is exported, the export is updated too.\n" +
               "Example:\n" +
               "  (%module-bind '(scheme base) 'car new-car-impl)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        var module = modules.getModuleRequired(pos, Modules.asModuleName(arguments[0]));
        var symbol = Value.asSymbol(arguments[1]);
        var value = arguments[2];
        String origin = module.provenance.getOrDefault(symbol, module.getName());
        module.bind(symbol, value, origin);
        if (module.exports.containsKey(symbol)) {
            // bind mutated the existing cell in place (or created a fresh one);
            // either way, point exports at the current cell so any sharing
            // importers see the new value too.
            module.exports.put(symbol, module.bindings.get(symbol));
        }
        return Value.T;
    }
}
