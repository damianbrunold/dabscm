package scheme.primitives;

import scheme.*;
import java.io.ByteArrayOutputStream;

public class PrimitiveOpenOutputBytevector extends Primitive {
    @Override public String name() { return "open-output-bytevector"; }
    @Override public String info() {
        return "Syntax: (open-output-bytevector)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a binary output port that accumulates bytes in memory. Use get-output-bytevector to retrieve the accumulated bytes.\n" +
               "Example:\n" +
               "  (let ((p (open-output-bytevector)))\n" +
               "    (write-u8 65 p)\n" +
               "    (get-output-bytevector p)) => #u8(65)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return new BinaryOutputStream(new ByteArrayOutputStream(), true);
    }
}
