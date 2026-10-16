package scheme.primitives;

import scheme.*;

public class PrimitiveChaCha20PortP extends Primitive {
    @Override public String name() { return "chacha20-port?"; }
    @Override public String info() {
        return "Syntax: (chacha20-port? obj)\n" +
               "Library: (srfi 271 determinized)\n" +
               "Description: Returns #t if obj is a port made by make-chacha20-port.\n" +
               "Example:\n" +
               "  (chacha20-port? (make-chacha20-port (make-bytevector 32 1) 0 0)) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return arguments[0] instanceof BinaryInputStream
            && ((BinaryInputStream) arguments[0]).getSource() instanceof ChaCha20InputStream;
    }
}
