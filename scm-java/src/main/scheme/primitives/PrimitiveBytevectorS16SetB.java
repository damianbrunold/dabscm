package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorS16SetB extends Primitive {
    @Override public String name() { return "bytevector-s16-set!"; }
    @Override public String info() {
        return "Syntax: (bytevector-s16-set! bv k n endianness)\n" +
               "Library: (scm bytevector)\n" +
               "Description: Stores the exact integer n, which must be in [-32768, 32767], as\n" +
               "  an signed 16-bit integer at byte index k of bv. The 2 bytes at k must lie\n" +
               "  within bv; endianness is the symbol big or little.\n" +
               "Example:\n" +
               "  (let ((bv (make-bytevector 2 0))) (bytevector-s16-set! bv 0 -2 'little) bv) => #u8(254 255)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 4, 4);
        byte[] bv = Value.asBytevector(arguments[0]);
        int k = BytevectorNumbers.index(pos, name(), bv, arguments[1], 2);
        boolean little = BytevectorNumbers.little(pos, name(), arguments[3]);
        BytevectorNumbers.writeInt(pos, name(), bv, k, 2, true, arguments[2], little);
        return new Values();
    }
}
