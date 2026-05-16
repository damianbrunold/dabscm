package scheme.primitives;

import scheme.*;

public class PrimitiveExpt extends Primitive {
    @Override
    public String name() {
        return "expt";
    }

    @Override
    public String info() {
        return "Syntax: (expt z1 z2)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns z1 raised to the power z2. If z2 is exact 0, returns exact 1.\n" +
               "Example:\n" +
               "  (expt 2 10) => 1024\n" +
               "  (expt 4 0) => 1\n" +
               "  (expt 2.0 3) => 8.0";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        if (allIntegers(arguments)) {
            long b = IntegerMath.toLong(arguments[1]);
            if (b == 0) return 1L;
            if (b > 0) {
                return IntegerMath.expt(arguments[0], b);
            } else {
                return Rational.div(1L, IntegerMath.expt(arguments[0], -b));
            }
        } else {
            double a = toReal(arguments[0]);
            double b = toReal(arguments[1]);
            if (b == 0.0) return 1.0;
            return Math.pow(a, b);
        }
    }
}
