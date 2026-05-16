package scheme.primitives;

import scheme.*;

public class PrimitiveAcos extends Primitive {
    @Override
    public String name() {
        return "acos";
    }

    @Override
    public String info() {
        return "Syntax: (acos z)\n" +
               "Library: (scheme inexact)\n" +
               "Description: Returns the arc cosine of z. The result is in radians.\n" +
               "Example:\n" +
               "  (acos 1.0) => 0.0\n" +
               "  (acos 0.0) => 1.5707963267948966";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Math.acos(toReal(arguments[0]));
    }
}
