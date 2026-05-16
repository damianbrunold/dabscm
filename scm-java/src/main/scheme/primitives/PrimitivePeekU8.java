package scheme.primitives;

import scheme.*;

public class PrimitivePeekU8 extends Primitive {
    @Override public String name() { return "peek-u8"; }
    @Override public String info() {
        return "Syntax: (peek-u8 port)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the next byte available from the binary input port without consuming it. Returns an end-of-file object if no bytes are available.\n" +
               "Example:\n" +
               "  (let ((p (open-input-bytevector #u8(10 20))))\n" +
               "    (peek-u8 p)) => 10";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        try {
            BinaryInputStream port = Value.asBinaryInputPort(arguments[0]);
            int b = port.peekByte();
            return b == -1 ? (Object) Value.EOF : (Object) (long) (b & 0xFF);
        } catch (Exception e) {
            throw new SchemeError(pos, "peek-u8: io failure: ~a", e.getMessage());
        }
    }
}
