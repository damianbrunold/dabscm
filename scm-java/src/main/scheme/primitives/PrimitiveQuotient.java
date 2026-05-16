package scheme.primitives;

import scheme.*;

public class PrimitiveQuotient extends Primitive {
    @Override
    public String name() {
        return "quotient";
    }

    @Override
    public String info() {
        return "Syntax: (quotient n1 n2)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the integer quotient of n1 divided by n2, truncated toward zero.\n" +
               "Example:\n" +
               "  (quotient 13 4) => 3";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        if (allIntegers(arguments)) {
            return IntegerMath.genericQuotient(arguments[0], arguments[1]);
        }
        else {
            return (double) ((long) (toReal(arguments[0]) / toReal(arguments[1])));
        }
    }
}
