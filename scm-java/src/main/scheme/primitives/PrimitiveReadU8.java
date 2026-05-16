package scheme.primitives;

import scheme.*;

public class PrimitiveReadU8 extends Primitive {
    @Override public String name() { return "read-u8"; }
    @Override public String info() {
        return "Syntax: (read-u8 port)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the next byte available from the binary input port as an exact integer in the range 0 to 255. Returns an end-of-file object if no bytes are available.\n" +
               "Example:\n" +
               "  (let ((p (open-input-bytevector #u8(65 66))))\n" +
               "    (read-u8 p)) => 65";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        try {
            BinaryInputStream port = Value.asBinaryInputPort(arguments[0]);
            int b = port.readByte();
            return b == -1 ? (Object) Value.EOF : (Object) (long) (b & 0xFF);
        } catch (Exception e) {
            throw new SchemeError(pos, "read-u8: io failure: ~a", e.getMessage());
        }
    }
}
