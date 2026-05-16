package scheme.primitives;

import scheme.*;

import java.io.Writer;

public class PrimitiveWrite extends Primitive {
    private Modules modules;

    public PrimitiveWrite(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "write";
    }

    @Override
    public String info() {
        return "Syntax: (write obj port?)\n" +
               "Library: (scheme write)\n" +
               "Description: Writes a machine-readable representation of obj to the given port, or the current output port. Strings are written with quotes and special characters escaped.\n" +
               "Example:\n" +
               "  (write '(1 \"two\" #\\3)) => (1 \"two\" #\\3)\n" +
               "  (write 'hello) => hello";
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
            Value.printRepCyclicTo(arguments[0], port);
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~s", e.getMessage());
        }
    }
}
