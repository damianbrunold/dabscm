package scheme.primitives;

import scheme.*;

public class PrimitiveBitwiseNot extends Primitive {
    @Override
    public String name() {
        return "bitwise-not";
    }

    @Override
    public String info() {
        return "Syntax: (bitwise-not i)\n" +
               "Library: (srfi 151)\n" +
               "Description: Returns the bitwise complement of i.\n" +
               "Example:\n" +
               "  (bitwise-not 10) => -11\n" +
               "  (bitwise-not -1) => 0\n" +
               "  (bitwise-not 0) => -1";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return IntegerMath.bitwiseNot(arguments[0]);
    }
}
