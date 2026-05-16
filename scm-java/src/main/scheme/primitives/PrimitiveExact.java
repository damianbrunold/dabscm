package scheme.primitives;

import scheme.*;

public class PrimitiveExact extends Primitive {
    @Override
    public String name() {
        return "exact";
    }

    @Override
    public String info() {
        return "Syntax: (exact z)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the exact number that is numerically equal to z.\n" +
               "  For inexact integers, returns the integer. For non-integral inexact\n" +
               "  numbers, returns the simplest exact rational whose inexact value\n" +
               "  equals z (using continued fraction approximation).\n" +
               "Example:\n" +
               "  (exact 1.5) => 3/2\n" +
               "  (exact 0.3) => 3/10\n" +
               "  (exact 3.0) => 3\n" +
               "  (exact 3) => 3";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isComplex(arguments[0])) {
            Complex c = Value.asComplex(arguments[0]);
            return Complex.create(Complex.toExact(c.real), Complex.toExact(c.imag));
        }
        if (Value.isInteger(arguments[0])) return arguments[0];
        if (Value.isRational(arguments[0])) return arguments[0];
        double d = Value.asReal(arguments[0]);

        if (Double.isNaN(d) || Double.isInfinite(d))
            throw new SchemeError(pos, "exact: no exact representation for ~a", arguments[0]);

        // Integral doubles -> integer
        if (d == Math.floor(d)) {
            if (d >= Long.MIN_VALUE && d <= Long.MAX_VALUE)
                return (long) d;
            else
                return IntegerMath.normalize(new java.math.BigDecimal(d).toBigInteger());
        }

        // Non-integral doubles -> simplest exact rational via continued fractions.
        // Finds the rational with the smallest denominator whose (double) value
        // equals d. E.g. 0.3 -> 3/10 (since (double)(3/10) == 0.3).
        return doubleToRational(d);
    }

    /**
     * Convert a non-integral double to the simplest rational whose double
     * representation equals d, using the continued fraction algorithm.
     */
    private static Object doubleToRational(double d) {
        boolean negative = d < 0;
        double x = Math.abs(d);

        // Continued fraction convergents: p[-1]/q[-1] = 1/0, p[0]/q[0] = 0/1
        long p0 = 0, q0 = 1;
        long p1 = 1, q1 = 0;

        double rem = x;
        for (int i = 0; i < 100; i++) { // safety limit
            long a = (long) Math.floor(rem);

            // Next convergent: p2/q2 = a * p1 + p0, a * q1 + q0
            long p2 = a * p1 + p0;
            long q2 = a * q1 + q0;

            // Check if this convergent equals d when converted back to double
            if (q2 != 0 && (double) p2 / (double) q2 == x) {
                if (negative) p2 = -p2;
                if (q2 == 1) return p2;
                return Rational.create(p2, q2);
            }

            // Prepare for next iteration
            double frac = rem - a;
            if (frac == 0.0) break; // exact integer (shouldn't reach here)
            rem = 1.0 / frac;

            p0 = p1; q0 = q1;
            p1 = p2; q1 = q2;

            // Guard against overflow
            if (p1 > Long.MAX_VALUE / 1000 || q1 > Long.MAX_VALUE / 1000) break;
        }

        // Fallback: return the last convergent even if not exact
        if (negative) p1 = -p1;
        if (q1 == 1) return p1;
        return Rational.create(p1, q1);
    }
}
