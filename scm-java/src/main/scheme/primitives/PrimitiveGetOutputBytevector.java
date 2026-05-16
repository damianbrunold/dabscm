package scheme.primitives;

import scheme.*;

public class PrimitiveGetOutputBytevector extends Primitive {
    @Override public String name() { return "get-output-bytevector"; }
    @Override public String info() {
        return "Syntax: (get-output-bytevector port)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a bytevector consisting of the bytes that have been output to the given bytevector output port (created with open-output-bytevector).\n" +
               "Example:\n" +
               "  (let ((p (open-output-bytevector)))\n" +
               "    (write-u8 65 p)\n" +
               "    (get-output-bytevector p)) => #u8(65)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.asBinaryOutputPort(arguments[0]).getBytes();
    }
}
