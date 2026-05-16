package scheme.primitives;

import scheme.*;

import java.io.Writer;

public class PrimitiveWriteShared extends Primitive {
    private Modules modules;

    public PrimitiveWriteShared(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "write-shared";
    }

    @Override
    public String info() {
        return "Syntax: (write-shared obj port?)\n" +
               "Library: (scheme write)\n" +
               "Description: Writes obj to the given port using datum labels (#N= and #N#) to represent all shared and cyclic structure.\n" +
               "Example:\n" +
               "  (let ((x (list 1 2))) (write-shared x)) => (1 2)\n" +
               "  (write-shared '#0=(a . #0#)) => #0=(a . #0#)";
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
            Value.printRepSharedTo(arguments[0], port);
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~s", e.getMessage());
        }
    }
}
