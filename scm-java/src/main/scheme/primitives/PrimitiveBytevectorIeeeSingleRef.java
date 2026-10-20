package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorIeeeSingleRef extends Primitive {
    @Override public String name() { return "bytevector-ieee-single-ref"; }
    @Override public String info() {
        return "Syntax: (bytevector-ieee-single-ref bv k endianness)\n" +
               "Library: (scm bytevector)\n" +
               "Description: Returns the IEEE 754 single-precision float stored at byte index k of bv,\n" +
               "  as an inexact real. The 4 bytes at k must lie within bv;\n" +
               "  endianness is the symbol big or little.\n" +
               "Example:\n" +
               "  (bytevector-ieee-single-ref #u8(0 0 128 63) 0 'little) => 1.0";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        byte[] bv = Value.asBytevector(arguments[0]);
        int k = BytevectorNumbers.index(pos, name(), bv, arguments[1], 4);
        boolean little = BytevectorNumbers.little(pos, name(), arguments[2]);
        return (double) BytevectorNumbers.readSingle(bv, k, little);
    }
}
