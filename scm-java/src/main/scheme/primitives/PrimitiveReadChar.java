package scheme.primitives;

import scheme.*;

public class PrimitiveReadChar extends Primitive {
    private Modules modules;

    public PrimitiveReadChar(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "read-char";
    }

    @Override
    public String info() {
        return "Syntax: (read-char)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the next character available from the input port, updating the port to point past the character. If no more characters are available, an end-of-file object is returned. If port is omitted, the current input port is used.\n" +
               "Example:\n" +
               "  (define p (open-input-string \"ab\"))\n" +
               "  (read-char p) => #\\a\n" +
               "  (read-char p) => #\\b";
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
            int ch = port.read();
            if (ch == -1) return Value.EOF;
            return (char) ch;
        } catch (Exception e) {
            throw new SchemeError(pos, "read-char: io failure: ~s", e.getMessage());
        }
    }
}
