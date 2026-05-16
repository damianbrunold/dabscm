package scheme.primitives;

import scheme.*;

/**
 * Returns the name of the current module as a Scheme string.
 * Used by the macro system to capture the definition-site module.
 */
public class PrimitiveCurrentModuleName extends Primitive {
    private final Modules modules;

    public PrimitiveCurrentModuleName(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() { return "%current-module-name"; }

    @Override
    public String info() {
        return "Syntax: (%current-module-name)\n" +
               "Library: (scm core)\n" +
               "Description: Returns the name of the current module as a string.\n" +
               "Example:\n" +
               "  (%current-module-name) => \"user main\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return modules.getCurrentModule().getName().toCharArray();
    }
}
