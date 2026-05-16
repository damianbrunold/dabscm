package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorU8Ref extends Primitive {
    @Override public String name() { return "bytevector-u8-ref"; }
    @Override public String info() {
        return "Syntax: (bytevector-u8-ref bv k)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the byte at index k of bytevector bv as an exact integer in [0, 255].\n" +
               "Example:\n" +
               "  (bytevector-u8-ref #u8(1 2 3) 0) => 1\n" +
               "  (bytevector-u8-ref #u8(10 20 30) 2) => 30";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        byte[] bv = Value.asBytevector(arguments[0]);
        int k = IntegerMath.toInt(arguments[1]);
        if (k < 0 || k >= bv.length) throw new SchemeError(pos, "bytevector-u8-ref: index out of range: ~s", k);
        return (long) (bv[k] & 0xFF);
    }
}
