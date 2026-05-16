package scheme.primitives;

import scheme.*;
import java.io.ByteArrayInputStream;

public class PrimitiveOpenInputBytevector extends Primitive {
    @Override public String name() { return "open-input-bytevector"; }
    @Override public String info() {
        return "Syntax: (open-input-bytevector bv)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a binary input port that reads bytes from the bytevector bv.\n" +
               "Example:\n" +
               "  (let ((p (open-input-bytevector #u8(1 2 3))))\n" +
               "    (read-u8 p)) => 1";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        byte[] bv = Value.asBytevector(arguments[0]);
        return new BinaryInputStream(new ByteArrayInputStream(bv));
    }
}
