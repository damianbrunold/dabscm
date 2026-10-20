package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorIeeeSingleSetB extends Primitive {
    @Override public String name() { return "bytevector-ieee-single-set!"; }
    @Override public String info() {
        return "Syntax: (bytevector-ieee-single-set! bv k x endianness)\n" +
               "Library: (scm bytevector)\n" +
               "Description: Stores the real x as an IEEE 754 single-precision float at byte index k of bv\n" +
               "  (rounded to the nearest representable value). The 4 bytes at k\n" +
               "  must lie within bv; endianness is the symbol big or little.\n" +
               "Example:\n" +
               "  (let ((bv (make-bytevector 4 0))) (bytevector-ieee-single-set! bv 0 1.0 'big) bv) => #u8(63 128 0 0)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 4, 4);
        byte[] bv = Value.asBytevector(arguments[0]);
        int k = BytevectorNumbers.index(pos, name(), bv, arguments[1], 4);
        boolean little = BytevectorNumbers.little(pos, name(), arguments[3]);
        BytevectorNumbers.writeSingle(bv, k, (float) toReal(arguments[2]), little);
        return new Values();
    }
}
