package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorIeeeDoubleRef extends Primitive {
    @Override public String name() { return "bytevector-ieee-double-ref"; }
    @Override public String info() {
        return "Syntax: (bytevector-ieee-double-ref bv k endianness)\n" +
               "Library: (scm bytevector)\n" +
               "Description: Returns the IEEE 754 double-precision float stored at byte index k of bv,\n" +
               "  an exact integer None. The 8 bytes at k must lie within bv;\n" +
               "  endianness is the symbol big or little.\n" +
               "Example:\n" +
               "  (bytevector-ieee-double-ref #u8(0 0 0 0 0 0 240 63) 0 'little) => 1.0";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        byte[] bv = Value.asBytevector(arguments[0]);
        int k = BytevectorNumbers.index(pos, name(), bv, arguments[1], 8);
        boolean little = BytevectorNumbers.little(pos, name(), arguments[2]);
        return BytevectorNumbers.readDouble(bv, k, little);
    }
}
