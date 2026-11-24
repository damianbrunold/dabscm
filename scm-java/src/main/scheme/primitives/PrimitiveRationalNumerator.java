package scheme.primitives;

import scheme.*;

public class PrimitiveRationalNumerator extends Primitive {
    @Override public String name() { return "rational-numerator"; }
    @Override public String info() {
        return "Syntax: (rational-numerator q)\n" +
               "Library: (scm core)\n" +
               "Description: Returns the numerator of the rational number q in lowest terms. Returns q itself for integers.\n" +
               "  For inexact rational numbers, returns the numerator as an inexact number.\n" +
               "Example:\n" +
               "  (rational-numerator 1/3) => 1\n" +
               "  (rational-numerator 5)   => 5\n" +
               "  (rational-numerator 1.5) => 3.0";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isInteger(arguments[0])) return arguments[0];
        if (Value.isRational(arguments[0])) return Value.asRational(arguments[0]).numerator;
        if (Value.isReal(arguments[0])) {
            double d = (double) arguments[0];
            if (!Double.isFinite(d))
                throw new SchemeError(pos, "numerator: not a rational number: ~s", d);
            return doubleNumerator(d);
        }
        throw new SchemeError(pos, "numerator: not a rational number: ~s", arguments[0]);
    }

    static double doubleNumerator(double d) {
        if (d == 0.0) return 0.0;
        return doubleToReducedParts(d)[0];
    }

    // The numerator and denominator of the exact value of d, as doubles.
    static double[] doubleToReducedParts(double d) {
        if (d == 0.0) return new double[] { d, 1.0 };
        Object x = Complex.toExact(d);
        if (Value.isRational(x)) {
            Rational q = Value.asRational(x);
            return new double[] { IntegerMath.toDouble(q.numerator), IntegerMath.toDouble(q.denominator) };
        }
        return new double[] { d, 1.0 };
    }
}
