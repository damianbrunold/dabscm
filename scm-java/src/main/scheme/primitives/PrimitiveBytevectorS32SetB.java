package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorS32SetB extends Primitive {
    @Override public String name() { return "bytevector-s32-set!"; }
    @Override public String info() {
        return "Syntax: (bytevector-s32-set! bv k n endianness)\n" +
               "Library: (scm bytevector)\n" +
               "Description: Stores the exact integer n, which must be in [-2147483648, 2147483647], as\n" +
               "  an signed 32-bit integer at byte index k of bv. The 4 bytes at k must lie\n" +
               "  within bv; endianness is the symbol big or little.\n" +
               "Example:\n" +
               "  (let ((bv (make-bytevector 4 0))) (bytevector-s32-set! bv 0 -1 'big) bv) => #u8(255 255 255 255)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 4, 4);
        byte[] bv = Value.asBytevector(arguments[0]);
        int k = BytevectorNumbers.index(pos, name(), bv, arguments[1], 4);
        boolean little = BytevectorNumbers.little(pos, name(), arguments[3]);
        BytevectorNumbers.writeInt(pos, name(), bv, k, 4, true, arguments[2], little);
        return new Values();
    }
}
