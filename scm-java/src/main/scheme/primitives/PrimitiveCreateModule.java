package scheme.primitives;

import scheme.Modules;
import scheme.Primitive;
import scheme.SourcePos;

public class PrimitiveCreateModule extends Primitive
{
    private Modules modules;

    public PrimitiveCreateModule(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "%create-module";
    }

    @Override
    public String info() {
        return "Syntax: (%create-module module-name)\n" +
               "Library: (scm core)\n" +
               "Description: Creates the named module if it does not already exist. Returns the module name.\n" +
               "Example:\n" +
               "  (create-module '(my lib))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);

        var oldModule = modules.getCurrentModule();
        modules.setCurrentModule(Modules.asModuleName(arguments[0]));
        modules.setCurrentModule(oldModule.getName());
        return arguments[0];
    }
}
