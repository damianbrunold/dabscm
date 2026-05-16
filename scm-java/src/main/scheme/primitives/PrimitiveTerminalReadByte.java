package scheme.primitives;

import scheme.*;

public class PrimitiveTerminalReadByte extends Primitive {
    @Override
    public String name() {
        return "terminal-read-byte";
    }

    @Override
    public String info() {
        return "Syntax: (terminal-read-byte)\n" +
               "Library: (scm terminal)\n" +
               "Description: Reads a single raw byte from standard input, bypassing\n" +
               "the port system and any line buffering. Returns an integer 0-255,\n" +
               "or an eof-object if the end of input has been reached.\n" +
               "Intended for use in raw terminal mode.\n" +
               "Example:\n" +
               "  (terminal-read-byte) => 27  ; ESC key";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        try {
            int b = System.in.read();
            if (b == -1)
                return Value.EOF;
            return b;
        } catch (Exception e) {
            throw new SchemeError(pos, "terminal-read-byte: io failure: ~a", e.getMessage());
        }
    }
}
