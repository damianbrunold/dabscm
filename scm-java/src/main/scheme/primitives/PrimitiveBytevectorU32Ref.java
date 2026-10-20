package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorU32Ref extends Primitive {
    @Override public String name() { return "bytevector-u32-ref"; }
    @Override public String info() {
        return "Syntax: (bytevector-u32-ref bv k endianness)\n" +
               "Library: (scm bytevector)\n" +
               "Description: Returns the unsigned 32-bit integer stored at byte index k of bv,\n" +
               "  an exact integer in [0, 4294967295]. The 4 bytes at k must lie within bv;\n" +
               "  endianness is the symbol big or little.\n" +
               "Example:\n" +
               "  (bytevector-u32-ref #u8(0 0 1 0) 0 'big) => 256";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        byte[] bv = Value.asBytevector(arguments[0]);
        int k = BytevectorNumbers.index(pos, name(), bv, arguments[1], 4);
        boolean little = BytevectorNumbers.little(pos, name(), arguments[2]);
        return BytevectorNumbers.readU(bv, k, 4, little);
    }
}
