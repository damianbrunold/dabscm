package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorS16Ref extends Primitive {
    @Override public String name() { return "bytevector-s16-ref"; }
    @Override public String info() {
        return "Syntax: (bytevector-s16-ref bv k endianness)\n" +
               "Library: (scm bytevector)\n" +
               "Description: Returns the signed 16-bit integer stored at byte index k of bv,\n" +
               "  an exact integer in [-32768, 32767]. The 2 bytes at k must lie within bv;\n" +
               "  endianness is the symbol big or little.\n" +
               "Example:\n" +
               "  (bytevector-s16-ref #u8(255 255) 0 'big) => -1";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        byte[] bv = Value.asBytevector(arguments[0]);
        int k = BytevectorNumbers.index(pos, name(), bv, arguments[1], 2);
        boolean little = BytevectorNumbers.little(pos, name(), arguments[2]);
        return BytevectorNumbers.readS(bv, k, 2, little);
    }
}
