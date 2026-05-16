package scheme.primitives;

import scheme.*;

public class PrimitiveBinaryPortP extends Primitive {
    @Override public String name() { return "binary-port?"; }
    @Override public String info() {
        return "Syntax: (binary-port? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is a binary port, otherwise returns #f.\n" +
               "Example:\n" +
               "  (binary-port? (open-input-bytevector #u8(1 2 3))) => #t\n" +
               "  (binary-port? (open-input-string \"abc\")) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isBinaryInputPort(arguments[0]) || Value.isBinaryOutputPort(arguments[0]);
    }
}
