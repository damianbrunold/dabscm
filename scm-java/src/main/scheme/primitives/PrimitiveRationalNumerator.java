package scheme.primitives;

import scheme.*;

public class PrimitiveRationalNumerator extends Primitive {
    @Override public String name() { return "rational-numerator"; }
    @Override public String info() {
        return "Syntax: (rational-numerator q)\n" +
               "Library: (scheme base)\n" +
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
                throw new SchemeError(pos, "numerator: not a rational number: " + d);
            return doubleNumerator(d);
        }
        throw new SchemeError(pos, "numerator: not a rational number: ~s", arguments[0]);
    }

    static double doubleNumerator(double d) {
        if (d == 0.0) return 0.0;
        return doubleToReducedParts(d)[0];
    }

    static double[] doubleToReducedParts(double d) {
        boolean negative = d < 0;
        double absD = Math.abs(d);
        long bits = Double.doubleToLongBits(absD);
        long mant = bits & 0x000FFFFFFFFFFFFFL;
        int biasedExp = (int) ((bits >> 52) & 0x7FFL);
        long n;
        int shift;
        if (biasedExp == 0) {
            n = mant;
            shift = 1074;
        } else {
            n = mant | (1L << 52);
            shift = 1023 + 52 - biasedExp;
        }
        if (shift <= 0) {
            double numD = negative ? -absD : absD;
            return new double[]{numD, 1.0};
        }
        int tz = trailingZeros64(n);
        int reduce = Math.min(tz, shift);
        n >>= reduce;
        shift -= reduce;
        double num = negative ? -(double) n : (double) n;
        double den = shift <= 62 ? (double) (1L << shift) : Double.POSITIVE_INFINITY;
        return new double[]{num, den};
    }

    private static int trailingZeros64(long n) {
        if (n == 0) return 64;
        int count = 0;
        while ((n & 1L) == 0) { n >>= 1; count++; }
        return count;
    }
}
