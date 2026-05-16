package scheme.primitives;

import scheme.*;

public class PrimitiveSub extends Primitive {
    @Override
    public String name() {
        return "-";
    }

    @Override
    public String info() {
        return "Syntax: (- z ...)\n" +
               "Library: (scheme base)\n" +
               "Description: With a single argument, returns the negation of z. With two or more arguments, returns the result of subtracting each successive argument from the first.\n" +
               "Example:\n" +
               "  (- 10 3 2) => 5\n" +
               "  (- 5) => -5";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, -1);
        if (allIntegers(arguments)) {
            Object result = arguments[0];
            if (arguments.length == 1) {
                result = IntegerMath.genericNegate(result);
            } else {
                for (int i = 1; i < arguments.length; i++)
                    result = IntegerMath.genericSub(result, arguments[i]);
            }
            return result;
        } else if (allExactNums(arguments)) {
            if (arguments.length == 1)
                return Rational.sub(0L, arguments[0]);
            Object result = arguments[0];
            for (int i = 1; i < arguments.length; i++)
                result = Rational.sub(result, arguments[i]);
            return result;
        } else if (hasComplex(arguments)) {
            if (arguments.length == 1)
                return Complex.negate(arguments[0]);
            Object result = arguments[0];
            for (int i = 1; i < arguments.length; i++)
                result = Complex.sub(result, arguments[i]);
            return result;
        } else {
            double result = toReal(arguments[0]);
            if (arguments.length == 1) {
                result = -result;
            } else {
                for (int i = 1; i < arguments.length; i++)
                    result -= toReal(arguments[i]);
            }
            return result;
        }
    }
}
