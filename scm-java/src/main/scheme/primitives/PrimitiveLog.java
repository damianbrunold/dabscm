package scheme.primitives;

import scheme.*;

public class PrimitiveLog extends Primitive {
    @Override
    public String name() {
        return "log";
    }

    @Override
    public String info() {
        return "Syntax: (log z) (log z base)\n" +
               "Library: (scheme inexact)\n" +
               "Description: Returns the natural logarithm of z, or the logarithm of z to base if given.\n" +
               "Example:\n" +
               "  (log 1.0) => 0.0\n" +
               "  (log 8.0 2.0) => 3.0";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        if (arguments.length == 2) {
            Object a = log(arguments[0]), b = log(arguments[1]);
            if (a instanceof Double && b instanceof Double) return (double) (Double) a / (double) (Double) b;
            return Complex.div(a, b);
        }
        return log(arguments[0]);
    }

    // ln|z| + i angle(z); a real z < 0 (-0.0 too) has the imaginary part pi
    private Object log(Object z) {
        if (z instanceof Complex) return Complex.log(z);
        double x = toReal(z);
        if (x < 0 || (z instanceof Double && x == 0.0 && 1.0 / x < 0)) return Complex.log(x);
        return Math.log(x);
    }
}
