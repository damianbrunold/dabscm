package scheme.primitives;

import java.util.ArrayList;
import java.util.Collections;

import scheme.Modules;
import scheme.Pair;
import scheme.Primitive;
import scheme.SourcePos;

public class PrimitiveModuleDefinedBindings extends Primitive {
    private Modules modules;

    public PrimitiveModuleDefinedBindings(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "%module-defined-bindings";
    }

    @Override
    public String info() {
        return "Syntax: (%module-defined-bindings module-name)\n" +
               "Library: (scm core)\n" +
               "Description: Returns an alphabetically sorted list of all symbols\n" +
               "defined (not imported) in the named module. A symbol is considered\n" +
               "defined if its provenance matches the module's own name.\n" +
               "Example:\n" +
               "  (%module-defined-bindings '(scheme base))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);

        var module = modules.getModule(Modules.asModuleName(arguments[0]));
        var moduleName = module.getName();
        var symbols = new ArrayList<String>();
        for (var key : module.bindings.keySet()) {
            var origin = module.provenance.get(key);
            if (moduleName.equals(origin)) {
                symbols.add(key);
            }
        }
        Collections.sort(symbols);
        return Pair.list(symbols.toArray());
    }
}
