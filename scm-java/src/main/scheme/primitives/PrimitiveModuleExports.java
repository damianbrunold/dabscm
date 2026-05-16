package scheme.primitives;

import java.util.ArrayList;
import java.util.Collections;

import scheme.Modules;
import scheme.Pair;
import scheme.Primitive;
import scheme.SourcePos;
import scheme.SchemeError;

public class PrimitiveModuleExports extends Primitive {
    private Modules modules;

    public PrimitiveModuleExports(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "%module-exports";
    }

    @Override
    public String info() {
        return "Syntax: (%module-exports module-name)\n" +
               "Library: (scm core)\n" +
               "Description: Returns an alphabetically sorted list of all symbols exported by the named module.\n" +
               "Example:\n" +
               "  (%module-exports '(scheme base))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);

        var module = modules.getModule(Modules.asModuleName(arguments[0]));
        if (module == null) {
            throw new SchemeError(pos, name() + ": module ~a not found", arguments[0]);
        }
        var symbols = new ArrayList<String>(module.exports.keySet());
        Collections.sort(symbols);
        return Pair.list(symbols.toArray());
    }
}
