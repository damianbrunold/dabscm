package scheme.primitives;

import java.util.concurrent.atomic.AtomicInteger;

import scheme.Module;
import scheme.Modules;
import scheme.Primitive;
import scheme.SourcePos;
import scheme.Value;

public class PrimitiveEnvironment extends Primitive {
    private Modules modules;
    private static final AtomicInteger counter = new AtomicInteger(0);

    public PrimitiveEnvironment(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "environment";
    }

    @Override
    public String info() {
        return "Syntax: (environment lib ...)\n" +
               "Library: (scheme eval)\n" +
               "Description: Returns an environment specifier suitable for use with eval. Each lib must be a library name. With no arguments, returns the scm core environment.\n" +
               "Example:\n" +
               "  (eval '(+ 1 2) (environment '(scheme base))) => 3";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, -1);

        // No args: return scm core
        if (arguments.length == 0) {
            return "scm core".toCharArray();
        }

        // Single lib: ensure it is loaded and return it as-is for eval to use
        if (arguments.length == 1) {
            String moduleName = Modules.asModuleName(arguments[0]);
            if (modules.getModule(moduleName) == null) {
                new PrimitiveLoadModule(modules).apply(pos, new Object[] { arguments[0] });
            }
            return arguments[0];
        }

        // Multiple libs: create a fresh composite module and import all libs into it
        String name = "%environment-" + counter.incrementAndGet();
        Module originalModule = modules.getCurrentModule();
        try {
            modules.setCurrentModule(name);  // creates module if needed
            PrimitiveDoImportSet importSet = new PrimitiveDoImportSet(modules);
            for (Object arg : arguments) {
                importSet.apply(pos, new Object[] { arg });
            }
        } finally {
            modules.setCurrentModule(originalModule.getName());
        }
        return name.toCharArray();
    }
}
