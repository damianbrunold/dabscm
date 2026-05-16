package scheme.primitives;

import scheme.*;
import java.io.Writer;

public class PrimitiveTextualPortP extends Primitive {
    @Override public String name() { return "textual-port?"; }
    @Override public String info() {
        return "Syntax: (textual-port? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is a textual port (i.e., a port that reads or writes characters), #f otherwise.\n" +
               "Example:\n" +
               "  (textual-port? (current-input-port)) => #t\n" +
               "  (textual-port? (open-output-bytevector)) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return arguments[0] instanceof TextStream || arguments[0] instanceof Writer;
    }
}
