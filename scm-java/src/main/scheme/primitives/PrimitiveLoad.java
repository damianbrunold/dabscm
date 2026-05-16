package scheme.primitives;

import java.io.File;

import scheme.Module;
import scheme.Modules;
import scheme.Primitive;
import scheme.Scheme;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;

public class PrimitiveLoad extends Primitive {
    private Modules modules;

    public PrimitiveLoad(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "load";
    }

    @Override
    public String info() {
        return "Syntax: (load filename) (load filename environment)\n" +
               "Library: (scheme load)\n" +
               "Description: Reads and evaluates all expressions from the named Scheme source file. If an environment is given, evaluates in that module's environment.\n" +
               "Example:\n" +
               "  (load \"mylib.scm\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        String filename = new String(Value.asString(arguments[0]));
        try {
            Modules evalModules = modules;
            if (arguments.length == 2) {
                var moduleName = Modules.asModuleName(arguments[1]);
                Module module = modules.getModule(moduleName);
                if (module == null) {
                    var loadModule = (Primitive) modules.getModuleRequired(pos, "scm core").resolve(pos, "%load-module");
                    loadModule.apply(pos, new Object[] { arguments[1] });
                    module = modules.getModule(moduleName);
                }
                if (module == null)
                    throw new SchemeError(pos, "load: environment not found: ~a", moduleName);
                evalModules = new Modules(modules, module);
            }
            new Scheme(evalModules).evalFile(new File(filename));
            return Value.T;
        } catch (SchemeError e) {
            throw e;
        } catch (Exception e) {
            throw new SchemeError(pos, "load: cannot open '" + filename + "': " + e.getMessage());
        }
    }
}
