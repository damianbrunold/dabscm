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
        if (arguments[0] instanceof Complex) return Complex.acos(arguments[0]);
        double x = toReal(arguments[0]);
        // outside [-1, 1]: the principal complex value
        if (x < -1.0 || x > 1.0) return Complex.acos(x);
        return Math.acos(x);
    }
}
