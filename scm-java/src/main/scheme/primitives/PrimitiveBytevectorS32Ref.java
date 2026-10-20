package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorS32Ref extends Primitive {
    @Override public String name() { return "bytevector-s32-ref"; }
    @Override public String info() {
        return "Syntax: (bytevector-s32-ref bv k endianness)\n" +
               "Library: (scm bytevector)\n" +
               "Description: Returns the signed 32-bit integer stored at byte index k of bv,\n" +
               "  an exact integer in [-2147483648, 2147483647]. The 4 bytes at k must lie within bv;\n" +
               "  endianness is the symbol big or little.\n" +
               "Example:\n" +
               "  (bytevector-s32-ref #u8(255 255 255 255) 0 'little) => -1";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        byte[] bv = Value.asBytevector(arguments[0]);
        int k = BytevectorNumbers.index(pos, name(), bv, arguments[1], 4);
        boolean little = BytevectorNumbers.little(pos, name(), arguments[2]);
        return BytevectorNumbers.readS(bv, k, 4, little);
    }
}
