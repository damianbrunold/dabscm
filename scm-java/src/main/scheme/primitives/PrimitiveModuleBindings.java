package scheme.primitives;

import java.util.ArrayList;
import java.util.Collections;

import scheme.Modules;
import scheme.Pair;
import scheme.Primitive;
import scheme.SourcePos;
import scheme.SchemeError;

public class PrimitiveModuleBindings extends Primitive {
    private Modules modules;

    public PrimitiveModuleBindings(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "%module-bindings";
    }

    @Override
    public String info() {
        return "Syntax: (%module-bindings module-name)\n" +
               "Library: (scm core)\n" +
               "Description: Returns an alphabetically sorted list of all symbols bound in the named module.\n" +
               "Example:\n" +
               "  (%module-bindings '(scheme base))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);

        var module = modules.getModule(Modules.asModuleName(arguments[0]));
        if (module == null) {
            throw new SchemeError(pos, name() + ": module ~a not found", arguments[0]);
        }
        var symbols = new ArrayList<String>(module.bindings.keySet());
        Collections.sort(symbols);
        return Pair.list(symbols.toArray());
    }
}
