package scheme.primitives;

import scheme.Modules;
import scheme.Primitive;
import scheme.SourcePos;
import scheme.Value;

public class PrimitiveSetCurrentModule extends Primitive {
    private Modules modules;

    public PrimitiveSetCurrentModule(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "set-current-module";
    }

    @Override
    public String info() {
        return "Syntax: (set-current-module module-name)\n" +
               "Library: (scm core)\n" +
               "Description: Sets the specified module as the active module. Subsequent definitions will be made in that module.\n" +
               "Example:\n" +
               "  (set-current-module '(scm core))\n" +
               "  (current-module) => (scm core)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var moduleName = Modules.asModuleName(arguments[0]);
        modules.setCurrentModule(moduleName);
        return Value.T;
    }
}
