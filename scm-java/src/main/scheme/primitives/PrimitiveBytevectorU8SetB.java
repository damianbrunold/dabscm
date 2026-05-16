package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorU8SetB extends Primitive {
    @Override public String name() { return "bytevector-u8-set!"; }
    @Override public String info() {
        return "Syntax: (bytevector-u8-set! bv k byte)\n" +
               "Library: (scheme base)\n" +
               "Description: Stores byte (an exact integer in [0, 255]) into element k of bytevector bv.\n" +
               "Example:\n" +
               "  (let ((bv (bytevector 1 2 3)))\n" +
               "    (bytevector-u8-set! bv 1 42)\n" +
               "    bv) => #u8(1 42 3)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        byte[] bv = Value.asBytevector(arguments[0]);
        int k = IntegerMath.toInt(arguments[1]);
        long v = IntegerMath.toLong(arguments[2]);
        if (k < 0 || k >= bv.length) throw new SchemeError(pos, "bytevector-u8-set!: index out of range: ~s", k);
        if (v < 0 || v > 255) throw new SchemeError(pos, "bytevector-u8-set!: byte out of range: ~s", v);
        bv[k] = (byte) v;
        return new Values();
    }
}
