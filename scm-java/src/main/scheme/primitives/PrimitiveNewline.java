package scheme.primitives;

import scheme.*;

import java.io.Writer;

public class PrimitiveNewline extends Primitive {
    private Modules modules;

    public PrimitiveNewline(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "newline";
    }

    @Override
    public String info() {
        return "Syntax: (newline) (newline port)\n" +
               "Library: (scheme write)\n" +
               "Description: Writes a newline character to the current output port or to the given port.\n" +
               "Example:\n" +
               "  (newline)\n" +
               "  (newline (open-output-string))";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 1);
        Writer port;
        if (arguments.length == 0) {
            port = Value.asOutputPort(modules.getModuleRequired(pos, "scm core").resolve(pos, "*output-port*"));
        } else {
            port = Value.asOutputPort(arguments[0]);
        }
        try {
            port.write("\n");
            port.flush();
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, "newline: io failure: ~s", e.getMessage());
        }
    }
}
