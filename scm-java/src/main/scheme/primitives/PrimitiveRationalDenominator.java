package scheme.primitives;

import scheme.*;

public class PrimitiveRationalDenominator extends Primitive {
    @Override public String name() { return "rational-denominator"; }
    @Override public String info() {
        return "Syntax: (rational-denominator q)\n" +
               "Library: (scm core)\n" +
               "Description: Returns the denominator of the rational number q in lowest terms. Returns 1 for integers.\n" +
               "  For inexact rational numbers, returns the denominator as an inexact number.\n" +
               "Example:\n" +
               "  (rational-denominator 1/3) => 3\n" +
               "  (rational-denominator 5)   => 1\n" +
               "  (rational-denominator 1.5) => 2.0";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isInteger(arguments[0])) return 1L;
        if (Value.isRational(arguments[0])) return Value.asRational(arguments[0]).denominator;
        if (Value.isReal(arguments[0])) {
            double d = (double) arguments[0];
            if (!Double.isFinite(d))
                throw new SchemeError(pos, "denominator: not a rational number: " + d);
            return PrimitiveRationalNumerator.doubleToReducedParts(d)[1];
        }
        throw new SchemeError(pos, "denominator: not a rational number: ~s", arguments[0]);
    }
}
