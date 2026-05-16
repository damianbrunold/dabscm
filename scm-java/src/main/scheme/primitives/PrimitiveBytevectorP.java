package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorP extends Primitive {
    @Override public String name() { return "bytevector?"; }
    @Override public String info() {
        return "Syntax: (bytevector? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is a bytevector, otherwise returns #f.\n" +
               "Example:\n" +
               "  (bytevector? #u8(1 2 3)) => #t\n" +
               "  (bytevector? \"abc\") => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isBytevector(arguments[0]);
    }
}
