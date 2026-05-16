package scheme.primitives;

import scheme.*;

import java.io.Writer;

public class PrimitiveWriteChar extends Primitive {
    private Modules modules;

    public PrimitiveWriteChar(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "write-char";
    }

    @Override
    public String info() {
        return "Syntax: (write-char char port?)\n" +
               "Library: (scheme base)\n" +
               "Description: Writes the character char to the given textual output port, or to the current output port if no port is specified.\n" +
               "Example:\n" +
               "  (write-char #\\A) => (outputs A)\n" +
               "  (write-char #\\newline port)";
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
            port.write(Value.asChar(arguments[0]));
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, "write-char: io failure: ~s", e.getMessage());
        }
    }
}
