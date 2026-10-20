package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorIeeeDoubleSetB extends Primitive {
    @Override public String name() { return "bytevector-ieee-double-set!"; }
    @Override public String info() {
        return "Syntax: (bytevector-ieee-double-set! bv k n endianness)\n" +
               "Library: (scm bytevector)\n" +
               "Description: Stores the exact integer n, which must be None, as\n" +
               "  an IEEE 754 double-precision float at byte index k of bv. The 8 bytes at k must lie\n" +
               "  within bv; endianness is the symbol big or little.\n" +
               "Example:\n" +
               "  (let ((bv (make-bytevector 8 0))) (bytevector-ieee-double-set! bv 0 1.0 'big) bv) => #u8(63 240 0 0 0 0 0 0)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 4, 4);
        byte[] bv = Value.asBytevector(arguments[0]);
        int k = BytevectorNumbers.index(pos, name(), bv, arguments[1], 8);
        boolean little = BytevectorNumbers.little(pos, name(), arguments[3]);
        BytevectorNumbers.writeDouble(bv, k, toReal(arguments[2]), little);
        return new Values();
    }
}
