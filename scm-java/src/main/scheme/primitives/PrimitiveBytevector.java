package scheme.primitives;

import scheme.*;

public class PrimitiveBytevector extends Primitive {
    @Override public String name() { return "bytevector"; }
    @Override public String info() {
        return "Syntax: (bytevector byte ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a newly allocated bytevector containing the given byte values (each must be 0-255).\n" +
               "Example:\n" +
               "  (bytevector 1 2 3) => #u8(1 2 3)\n" +
               "  (bytevector) => #u8()";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        byte[] bv = new byte[arguments.length];
        for (int i = 0; i < arguments.length; i++) {
            long v = IntegerMath.toLong(arguments[i]);
            if (v < 0 || v > 255) throw new SchemeError(pos, "bytevector: element out of range: ~s", v);
            bv[i] = (byte) v;
        }
        return bv;
    }
}
