package scheme.primitives;

import scheme.*;

public class PrimitiveReadBytevectorB extends Primitive {
    @Override public String name() { return "read-bytevector!"; }
    @Override public String info() {
        return "Syntax: (read-bytevector! bv port)\n" +
               "Library: (scheme base)\n" +
               "Description: Reads bytes from the binary input port into the bytevector bv, starting at start (default 0) and ending before end (default length of bv). Returns the number of bytes read, or an end-of-file object if no bytes were available.\n" +
               "Example:\n" +
               "  (let ((bv (make-bytevector 3 0))\n" +
               "        (p (open-input-bytevector #u8(1 2 3))))\n" +
               "    (read-bytevector! bv p)\n" +
               "    bv) => #u8(1 2 3)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 4);
        try {
            byte[] bv = Value.asBytevector(arguments[0]);
            BinaryInputStream port = Value.asBinaryInputPort(arguments[1]);
            int start = arguments.length >= 3 ? IntegerMath.toInt(arguments[2]) : 0;
            int end = arguments.length >= 4 ? IntegerMath.toInt(arguments[3]) : bv.length;
            int count = end - start;
            int read = count > 0 ? port.read(bv, start, count) : 0;
            return read == 0 ? (Object) Value.EOF : (Object) (long) read;
        } catch (Exception e) {
            throw new SchemeError(pos, "read-bytevector!: io failure: ~a", e.getMessage());
        }
    }
}
