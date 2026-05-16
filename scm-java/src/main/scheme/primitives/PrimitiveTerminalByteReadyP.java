package scheme.primitives;

import scheme.*;

public class PrimitiveTerminalByteReadyP extends Primitive {
    @Override
    public String name() {
        return "terminal-byte-ready?";
    }

    @Override
    public String info() {
        return "Syntax: (terminal-byte-ready?)\n" +
               "Library: (scm terminal)\n" +
               "Description: Returns #t if a byte is available for reading from\n" +
               "standard input without blocking, #f otherwise.\n" +
               "Intended for use in raw terminal mode to detect multi-byte\n" +
               "escape sequences.\n" +
               "Example:\n" +
               "  (terminal-byte-ready?) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        try {
            return System.in.available() > 0;
        } catch (Exception e) {
            return false;
        }
    }
}
