package scheme.primitives;

import scheme.*;

import java.io.Writer;

public class PrimitiveWriteSimple extends Primitive {
    private Modules modules;

    public PrimitiveWriteSimple(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "write-simple";
    }

    @Override
    public String info() {
        return "Syntax: (write-simple obj port?)\n" +
               "Library: (scheme write)\n" +
               "Description: Writes obj to the given port without performing shared-structure detection, making it faster but unable to handle cyclic data.\n" +
               "Example:\n" +
               "  (write-simple '(1 2 3)) => (1 2 3)\n" +
               "  (write-simple \"hello\") => \"hello\"";
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
            Value.printRepTo(arguments[0], port);
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~s", e.getMessage());
        }
    }
}
