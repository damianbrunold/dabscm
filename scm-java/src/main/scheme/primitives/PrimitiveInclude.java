package scheme.primitives;

import java.io.File;

import scheme.Modules;
import scheme.Primitive;
import scheme.Scheme;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;
import scheme.Values;

public class PrimitiveInclude extends Primitive {
    private Modules modules;

    public PrimitiveInclude(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "include";
    }

    @Override
    public String info() {
        return "Syntax: (include filename ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Loads and evaluates one or more Scheme source files in the current module's environment.\n" +
               "Example:\n" +
               "  (include \"helpers.scm\" \"utils.scm\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, -1);
        try {
            Scheme scheme = new Scheme(modules);
            for (var i = 0; i < arguments.length; i++) {
                String filename = new String(Value.asString(arguments[i]));
                scheme.evalFile(new File(filename));
            }
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure");
        }
    }
}
