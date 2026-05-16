package scheme.primitives;

import scheme.*;

public class PrimitiveMakeBytevector extends Primitive {
    @Override public String name() { return "make-bytevector"; }
    @Override public String info() {
        return "Syntax: (make-bytevector k) (make-bytevector k fill)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a newly allocated bytevector of k bytes. If fill is given, each byte is initialized to fill (0-255); otherwise each byte is 0.\n" +
               "Example:\n" +
               "  (make-bytevector 3) => #u8(0 0 0)\n" +
               "  (make-bytevector 3 5) => #u8(5 5 5)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        long k = IntegerMath.toLong(arguments[0]);
        if (k < 0) throw new SchemeError(pos, "make-bytevector: length must be non-negative: ~s", k);
        byte fill = 0;
        if (arguments.length == 2) {
            long f = IntegerMath.toLong(arguments[1]);
            if (f < 0 || f > 255) throw new SchemeError(pos, "make-bytevector: fill out of range: ~s", f);
            fill = (byte) f;
        }
        byte[] bv = new byte[(int) k];
        if (fill != 0)
            for (int i = 0; i < k; i++) bv[i] = fill;
        return bv;
    }
}
