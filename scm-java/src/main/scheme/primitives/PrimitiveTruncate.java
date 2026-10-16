package scheme.primitives;

import scheme.*;

public class PrimitiveTruncate extends Primitive {
    @Override
    public String name() {
        return "truncate";
    }

    @Override
    public String info() {
        return "Syntax: (truncate x)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the integer closest to x whose absolute value is not larger than the absolute value of x (rounds toward zero).\n" +
               "Example:\n" +
               "  (truncate 3.7) => 3.0\n" +
               "  (truncate -3.7) => -3.0";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isInteger(arguments[0])) {
            return arguments[0];
        } else if (Value.isRational(arguments[0])) {
            return Value.asRational(arguments[0]).truncate();
        } else {
            // stays inexact; also for infinities, NaN and beyond the long range
            double d = toReal(arguments[0]);
            return d < 0 ? Math.ceil(d) : Math.floor(d);
        }
    }
}
