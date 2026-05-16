package scheme.primitives;

import scheme.*;

public class PrimitiveAdd extends Primitive {
    @Override
    public String name() {
        return "+";
    }

    @Override
    public String info() {
        return "Syntax: (+ z1 ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the sum of its arguments. With no arguments, returns 0.\n" +
               "Example:\n" +
               "  (+ 3 4) => 7\n" +
               "  (+ 3) => 3\n" +
               "  (+) => 0";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        if (arguments.length == 0) return 0L;
        if (allIntegers(arguments)) {
            Object result = arguments[0];
            for (int i = 1; i < arguments.length; i++) {
                result = IntegerMath.genericAdd(result, arguments[i]);
            }
            return result;
        } else if (allExactNums(arguments)) {
            Object result = arguments[0];
            for (int i = 1; i < arguments.length; i++)
                result = Rational.add(result, arguments[i]);
            return result;
        } else if (hasComplex(arguments)) {
            Object result = arguments[0];
            for (int i = 1; i < arguments.length; i++)
                result = Complex.add(result, arguments[i]);
            return result;
        } else {
            double result = toReal(arguments[0]);
            for (int i = 1; i < arguments.length; i++) {
                result += toReal(arguments[i]);
            }
            return result;
        }
    }
}
