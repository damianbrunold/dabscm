package scheme.primitives;

import scheme.*;

public class PrimitiveDiv extends Primitive {
    @Override
    public String name() {
        return "/";
    }

    @Override
    public String info() {
        return "Syntax: (/ z1 z2 ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the quotient of dividing z1 by the remaining arguments. With one argument, returns the multiplicative inverse 1/z1.\n" +
               "Example:\n" +
               "  (/ 10 2) => 5\n" +
               "  (/ 10 2 5) => 1\n" +
               "  (/ 4) => 1/4";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, -1);
        if (allExactNums(arguments)) {
            if (arguments.length == 1) {
                if (Value.isInteger(arguments[0])) {
                    if (IntegerMath.isZero(arguments[0])) throw new SchemeError(pos, "/: Division by zero");
                    return Rational.create(1L, arguments[0]);
                } else {
                    Rational r = Value.asRational(arguments[0]);
                    return Rational.create(r.denominator, r.numerator);
                }
            }
            Object result = arguments[0];
            for (int i = 1; i < arguments.length; i++) {
                if (Value.isInteger(arguments[i]) && IntegerMath.isZero(arguments[i]))
                    throw new SchemeError(pos, "/: Division by zero");
                if (Value.isRational(arguments[i]) && IntegerMath.isZero(Value.asRational(arguments[i]).numerator))
                    throw new SchemeError(pos, "/: Division by zero");
                result = Rational.div(result, arguments[i]);
            }
            return result;
        } else if (hasComplex(arguments)) {
            if (arguments.length == 1)
                return Complex.div(1L, arguments[0]);
            Object result = arguments[0];
            for (int i = 1; i < arguments.length; i++)
                result = Complex.div(result, arguments[i]);
            return result;
        } else {
            if (arguments.length == 1) {
                double value = toReal(arguments[0]);
                if (value == 0.0) throw new SchemeError(pos, "/: Division by ~s", value);
                return 1.0 / value;
            }
            double dresult = toReal(arguments[0]);
            for (int i = 1; i < arguments.length; i++) {
                double value = toReal(arguments[i]);
                if (value == 0.0) throw new SchemeError(pos, "/: Division by ~s", value);
                dresult /= value;
            }
            return dresult;
        }
    }
}
