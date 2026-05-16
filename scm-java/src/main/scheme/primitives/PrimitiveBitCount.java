package scheme.primitives;

import scheme.*;

public class PrimitiveBitCount extends Primitive {
    @Override
    public String name() {
        return "bit-count";
    }

    @Override
    public String info() {
        return "Syntax: (bit-count i)\n" +
               "Library: (srfi 151)\n" +
               "Description: Returns the population count of i: the number of 1-bits for\n" +
               "non-negative i, or the number of 0-bits for negative i.\n" +
               "Example:\n" +
               "  (bit-count 10) => 2\n" +
               "  (bit-count -11) => 2\n" +
               "  (bit-count 0) => 0";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return IntegerMath.bitCount(arguments[0]);
    }
}
