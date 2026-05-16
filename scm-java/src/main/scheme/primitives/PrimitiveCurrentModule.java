package scheme.primitives;

import scheme.Modules;
import scheme.Primitive;
import scheme.SourcePos;

public class PrimitiveCurrentModule extends Primitive {
    private Modules modules;

    public PrimitiveCurrentModule(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "current-module";
    }

    @Override
    public String info() {
        return "Syntax: (current-module)\n" +
               "Library: (scm core)\n" +
               "Description: Returns the name declaration of the current module.\n" +
               "Example:\n" +
               "  (current-module) => (user main)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return modules.getCurrentModule().getDecl();
    }
}
