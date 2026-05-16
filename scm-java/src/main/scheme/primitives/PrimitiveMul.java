package scheme.primitives;

import scheme.*;

public class PrimitiveMul extends Primitive {
    @Override
    public String name() {
        return "*";
    }

    @Override
    public String info() {
        return "Syntax: (* z1 ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the product of its arguments. With no arguments, returns 1.\n" +
               "Example:\n" +
               "  (* 4 5) => 20\n" +
               "  (* 3) => 3\n" +
               "  (*) => 1";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        if (arguments.length == 0) return 1L;
        if (allIntegers(arguments)) {
            Object result = arguments[0];
            for (int i = 1; i < arguments.length; i++) {
                result = IntegerMath.genericMul(result, arguments[i]);
            }
            return result;
        } else if (allExactNums(arguments)) {
            Object result = arguments[0];
            for (int i = 1; i < arguments.length; i++)
                result = Rational.mul(result, arguments[i]);
            return result;
        } else if (hasComplex(arguments)) {
            Object result = arguments[0];
            for (int i = 1; i < arguments.length; i++)
                result = Complex.mul(result, arguments[i]);
            return result;
        } else {
            double result = toReal(arguments[0]);
            for (int i = 1; i < arguments.length; i++) {
                result *= toReal(arguments[i]);
            }
            return result;
        }
    }
}
