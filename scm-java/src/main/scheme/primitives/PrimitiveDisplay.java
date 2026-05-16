package scheme.primitives;

import scheme.*;

import java.io.Writer;

public class PrimitiveDisplay extends Primitive {
    private Modules modules;

    public PrimitiveDisplay(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "display";
    }

    @Override
    public String info() {
        return "Syntax: (display obj) (display obj port)\n" +
               "Library: (scheme write)\n" +
               "Description: Writes a human-readable representation of obj to the current output port or the given port. Strings are written without quotes; characters are written without the #\\ prefix.\n" +
               "Example:\n" +
               "  (display \"hello\") => hello\n" +
               "  (display #\\a) => a";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        Writer port;
        if (arguments.length == 1) {
            port = Value.asOutputPort(modules.getModuleRequired(pos, "scm core").resolve(pos, "*output-port*"));
        } else {
            port = Value.asOutputPort(arguments[1]);
        }
        try {
            Value.displayRepTo(arguments[0], port);
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~s", e.getMessage());
        }
    }
}
