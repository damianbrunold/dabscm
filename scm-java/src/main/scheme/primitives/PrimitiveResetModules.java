package scheme.primitives;

import scheme.Modules;
import scheme.Primitive;
import scheme.SourcePos;
import scheme.Value;

public class PrimitiveResetModules extends Primitive {
    private Modules modules;

    public PrimitiveResetModules(Modules globals) {
        this.modules = globals;
    }

    @Override
    public String name() {
        return "%reset-modules";
    }

    @Override
    public String info() {
        return "Syntax: (%reset-modules)\n" +
               "Library: (scm core)\n" +
               "Description: Clears all loaded modules except scm core, forcing libraries to be re-imported on next use. Used for testing and development.\n" +
               "Example:\n" +
               "  (%reset-modules)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        modules.resetModules();
        modules.getModuleRequired(pos, "scm core");
        modules.updateModuleVar();
        return Value.T;
    }
}
