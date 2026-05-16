package scheme.primitives;

import scheme.*;

public class PrimitivePeekChar extends Primitive {
    private Modules modules;

    public PrimitivePeekChar(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "peek-char";
    }

    @Override
    public String info() {
        return "Syntax: (peek-char)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the next character available from the input port without updating the port to point past the character. If no more characters are available, an end-of-file object is returned. If port is omitted, the current input port is used.\n" +
               "Example:\n" +
               "  (define p (open-input-string \"ab\"))\n" +
               "  (peek-char p) => #\\a\n" +
               "  (read-char p) => #\\a";
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
            int ch = port.peek();
            if (ch == -1) return Value.EOF;
            return (char) ch;
        } catch (Exception e) {
            throw new SchemeError(pos, "peek-char: io failure: ~s", e.getMessage());
        }
    }
}
