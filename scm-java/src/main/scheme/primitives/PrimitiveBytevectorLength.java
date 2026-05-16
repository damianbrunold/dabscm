package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorLength extends Primitive {
    @Override public String name() { return "bytevector-length"; }
    @Override public String info() {
        return "Syntax: (bytevector-length bv)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the number of bytes in the given bytevector.\n" +
               "Example:\n" +
               "  (bytevector-length #u8(1 2 3)) => 3";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return (long) Value.asBytevector(arguments[0]).length;
    }
}
