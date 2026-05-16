package scheme.primitives;

import scheme.*;

public class PrimitiveArithmeticShift extends Primitive {
    @Override
    public String name() {
        return "arithmetic-shift";
    }

    @Override
    public String info() {
        return "Syntax: (arithmetic-shift i count)\n" +
               "Library: (srfi 151)\n" +
               "Description: Returns i shifted left by count bits if count is positive, or\n" +
               "right by -count bits if count is negative. Right shifts are arithmetic\n" +
               "(sign-preserving).\n" +
               "Example:\n" +
               "  (arithmetic-shift 8 2) => 32\n" +
               "  (arithmetic-shift 32 -2) => 8\n" +
               "  (arithmetic-shift -1 -1) => -1";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        long count = IntegerMath.toLong(arguments[1]);
        return IntegerMath.arithmeticShift(arguments[0], count);
    }
}
