package scheme.primitives;

import scheme.*;

public class PrimitiveSecureRandomPortP extends Primitive {
    @Override public String name() { return "secure-random-port?"; }
    @Override public String info() {
        return "Syntax: (secure-random-port? obj)\n" +
               "Library: (srfi 271 randomized)\n" +
               "Description: Returns #t if obj is a port made by make-secure-random-port.\n" +
               "Example:\n" +
               "  (secure-random-port? (make-secure-random-port)) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return arguments[0] instanceof BinaryInputStream
            && ((BinaryInputStream) arguments[0]).getSource() instanceof SecureRandomInputStream;
    }
}
