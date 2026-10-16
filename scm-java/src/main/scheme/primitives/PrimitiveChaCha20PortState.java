package scheme.primitives;

import scheme.*;

public class PrimitiveChaCha20PortState extends Primitive {
    @Override public String name() { return "chacha20-port-state"; }
    @Override public String info() {
        return "Syntax: (chacha20-port-state port)\n" +
               "Library: (srfi 271 determinized)\n" +
               "Description: Returns the position of the ChaCha20 port as a vector\n" +
               "  #(key counter offset): the next byte read is byte offset of keystream\n" +
               "  block counter. A byte taken by peek-u8 counts as not yet read.\n" +
               "Example:\n" +
               "  (chacha20-port-state (make-chacha20-port (make-bytevector 32 0) 0 5))\n" +
               "    => #(#u8(0 ...) 0 5)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (!(arguments[0] instanceof BinaryInputStream)
                || !(((BinaryInputStream) arguments[0]).getSource() instanceof ChaCha20InputStream))
            throw new SchemeError(pos, "chacha20-port-state: not a ChaCha20 port");
        var port = (BinaryInputStream) arguments[0];
        var stream = (ChaCha20InputStream) port.getSource();
        long counter = stream.getCounter();
        long offset = stream.getOffset();
        if (port.hasPeekedByte()) {
            if (offset == 0) {
                counter--;
                offset = 63;
            } else {
                offset--;
            }
        }
        return new Object[] { stream.getKey(), counter, offset };
    }
}
