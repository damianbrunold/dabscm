package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorU16SetB extends Primitive {
    @Override public String name() { return "bytevector-u16-set!"; }
    @Override public String info() {
        return "Syntax: (bytevector-u16-set! bv k n endianness)\n" +
               "Library: (scm bytevector)\n" +
               "Description: Stores the exact integer n, which must be in [0, 65535], as\n" +
               "  an unsigned 16-bit integer at byte index k of bv. The 2 bytes at k must lie\n" +
               "  within bv; endianness is the symbol big or little.\n" +
               "Example:\n" +
               "  (let ((bv (make-bytevector 2 0))) (bytevector-u16-set! bv 0 513 'big) bv) => #u8(2 1)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 4, 4);
        byte[] bv = Value.asBytevector(arguments[0]);
        int k = BytevectorNumbers.index(pos, name(), bv, arguments[1], 2);
        boolean little = BytevectorNumbers.little(pos, name(), arguments[3]);
        BytevectorNumbers.writeInt(pos, name(), bv, k, 2, false, arguments[2], little);
        return new Values();
    }
}
