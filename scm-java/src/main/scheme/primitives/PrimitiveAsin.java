package scheme.primitives;

import scheme.*;

public class PrimitiveAsin extends Primitive {
    @Override
    public String name() {
        return "asin";
    }

    @Override
    public String info() {
        return "Syntax: (asin z)\n" +
               "Library: (scheme inexact)\n" +
               "Description: Returns the arc sine of z. The result is in radians.\n" +
               "Example:\n" +
               "  (asin 0.0) => 0.0\n" +
               "  (asin 1.0) => 1.5707963267948966";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (arguments[0] instanceof Complex) return Complex.asin(arguments[0]);
        double x = toReal(arguments[0]);
        // outside [-1, 1]: the principal complex value
        if (x < -1.0 || x > 1.0) return Complex.asin(x);
        return Math.asin(x);
    }
}
