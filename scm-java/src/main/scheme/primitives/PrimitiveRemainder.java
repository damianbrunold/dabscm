package scheme.primitives;

import scheme.*;

public class PrimitiveRemainder extends Primitive {
    @Override
    public String name() {
        return "remainder";
    }

    @Override
    public String info() {
        return "Syntax: (remainder n1 n2)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the remainder of dividing n1 by n2. The result has the same sign as n1. It is an error if n2 is zero.\n" +
               "Example:\n" +
               "  (remainder 13 4) => 1\n" +
               "  (remainder -13 4) => -1\n" +
               "  (remainder 13 -4) => 1";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        if (allIntegers(arguments)) {
            return IntegerMath.genericRemainder(arguments[0], arguments[1]);
        } else {
            return (double) ((long) (toReal(arguments[0]) % toReal(arguments[1])));
        }
    }
}
