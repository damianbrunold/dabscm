package scheme.primitives;

import scheme.*;

public class PrimitiveWriteBytevector extends Primitive {
    @Override public String name() { return "write-bytevector"; }
    @Override public String info() {
        return "Syntax: (write-bytevector bv port? start? end?)\n" +
               "Library: (scheme base)\n" +
               "Description: Writes the bytes of bytevector bv to binary output port, optionally restricted to the range [start, end).\n" +
               "Example:\n" +
               "  (write-bytevector #u8(1 2 3) port)\n" +
               "  (write-bytevector #u8(1 2 3 4 5) port 1 3)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 4);
        try {
            byte[] bv = Value.asBytevector(arguments[0]);
            BinaryOutputStream port = Value.asBinaryOutputPort(arguments[1]);
            int start = arguments.length >= 3 ? IntegerMath.toInt(arguments[2]) : 0;
            int end = arguments.length >= 4 ? IntegerMath.toInt(arguments[3]) : bv.length;
            for (int i = start; i < end; i++)
                port.writeByte(bv[i]);
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, "write-bytevector: io failure: ~a", e.getMessage());
        }
    }
}
