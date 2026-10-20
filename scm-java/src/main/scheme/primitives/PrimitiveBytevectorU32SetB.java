package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorU32SetB extends Primitive {
    @Override public String name() { return "bytevector-u32-set!"; }
    @Override public String info() {
        return "Syntax: (bytevector-u32-set! bv k n endianness)\n" +
               "Library: (scm bytevector)\n" +
               "Description: Stores the exact integer n, which must be in [0, 4294967295], as\n" +
               "  an unsigned 32-bit integer at byte index k of bv. The 4 bytes at k must lie\n" +
               "  within bv; endianness is the symbol big or little.\n" +
               "Example:\n" +
               "  (let ((bv (make-bytevector 4 0))) (bytevector-u32-set! bv 0 256 'little) bv) => #u8(0 1 0 0)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 4, 4);
        byte[] bv = Value.asBytevector(arguments[0]);
        int k = BytevectorNumbers.index(pos, name(), bv, arguments[1], 4);
        boolean little = BytevectorNumbers.little(pos, name(), arguments[3]);
        BytevectorNumbers.writeInt(pos, name(), bv, k, 4, false, arguments[2], little);
        return new Values();
    }
}
