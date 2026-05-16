package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorAppend extends Primitive {
    @Override public String name() { return "bytevector-append"; }
    @Override public String info() {
        return "Syntax: (bytevector-append bv ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a newly allocated bytevector whose elements are the concatenation of the elements of the given bytevectors.\n" +
               "Example:\n" +
               "  (bytevector-append #u8(0 1 2) #u8(3 4 5)) => #u8(0 1 2 3 4 5)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        int total = 0;
        for (Object arg : arguments)
            total += Value.asBytevector(arg).length;
        byte[] result = new byte[total];
        int offset = 0;
        for (Object arg : arguments) {
            byte[] bv = Value.asBytevector(arg);
            System.arraycopy(bv, 0, result, offset, bv.length);
            offset += bv.length;
        }
        return result;
    }
}
