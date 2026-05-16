package scheme.primitives;

import scheme.*;

public class PrimitiveReadLine extends Primitive {
    private Modules modules;

    public PrimitiveReadLine(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "read-line";
    }

    @Override
    public String info() {
        return "Syntax: (read-line)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the next line of text available from the input port as a string, discarding the newline. If end of file is reached before any characters are read, an end-of-file object is returned. If port is omitted, the current input port is used.\n" +
               "Example:\n" +
               "  (define p (open-input-string \"hello\\nworld\"))\n" +
               "  (read-line p) => \"hello\"\n" +
               "  (read-line p) => \"world\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 1);
        TextStream port;
        if (arguments.length == 0) {
            port = Value.asInputPort(modules.getModuleRequired(pos, "scm core").resolve(pos, "*input-port*"));
        } else {
            port = Value.asInputPort(arguments[0]);
        }
        try {
            var line = port.readLine();
            if (line == null) return Value.EOF;
            return line.toCharArray();
        } catch (Exception e) {
            throw new SchemeError(pos, "read-line: io failure: ~s", e.getMessage());
        }
    }
}
