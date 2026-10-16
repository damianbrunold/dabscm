package scheme.primitives;

import java.math.BigInteger;
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

    // The simplest rational (smallest denominator) that reads back as d: the
    // simplest one in d's rounding interval, halfway to the neighbouring
    // doubles with both ends included on a tie-to-even. Computed exactly, so
    // it works across the whole range, subnormals included.
    private static Object doubleToRational(double d) {
        boolean negative = d < 0;
        double x = Math.abs(d);   // > 0 and not integral (handled by the caller)
        BigInteger[] v = exactParts(x), prev = exactParts(Math.nextDown(x)), next = exactParts(Math.nextUp(x));
        BigInteger n = v[0], m = v[1];
        BigInteger loN = n.multiply(prev[1]).add(prev[0].multiply(m)), loD = m.multiply(prev[1]).shiftLeft(1);
        BigInteger hiN = n.multiply(next[1]).add(next[0].multiply(m)), hiD = m.multiply(next[1]).shiftLeft(1);
        boolean closed = (Double.doubleToLongBits(x) & 1) == 0;

        // Continued fraction of the simplest rational between lo and hi: take
        // an integer in the interval if there is one, else the common integer
        // part and continue with the reciprocals of the fractional parts
        // (which swaps the ends). hiD == 0 stands for +infinity.
        java.util.List<BigInteger> terms = new java.util.ArrayList<>();
        while (true) {
            BigInteger fl = loN.divide(loD);
            BigInteger c = closed && fl.multiply(loD).equals(loN) ? fl : fl.add(BigInteger.ONE);
            int cmp = hiD.signum() == 0 ? -1 : c.multiply(hiD).compareTo(hiN);
            if (cmp < 0 || (closed && cmp == 0)) { terms.add(c); break; }
            terms.add(fl);
            BigInteger nLoN = hiD, nLoD = hiN.subtract(fl.multiply(hiD));   // 1 / (hi - fl)
            BigInteger nHiN = loD, nHiD = loN.subtract(fl.multiply(loD));   // 1 / (lo - fl)
            loN = nLoN; loD = nLoD; hiN = nHiN; hiD = nHiD;
        }
        BigInteger p = terms.get(terms.size() - 1), q = BigInteger.ONE;
        for (int i = terms.size() - 2; i >= 0; i--) {
            BigInteger np = terms.get(i).multiply(p).add(q);
            q = p; p = np;
        }
        return Rational.create(IntegerMath.normalize(negative ? p.negate() : p), IntegerMath.normalize(q));
    }

    // x (finite, >= 0) as {num, den}.
    private static BigInteger[] exactParts(double x) {
        long bits = Double.doubleToLongBits(x);
        int biased = (int) ((bits >> 52) & 0x7FFL);
        long mantissa = bits & 0xFFFFFFFFFFFFFL;
        if (biased != 0) mantissa |= 1L << 52; else biased = 1;
        int exp = biased - 1023 - 52;
        BigInteger num = BigInteger.valueOf(mantissa), den = BigInteger.ONE;
        if (exp >= 0) num = num.shiftLeft(exp); else den = den.shiftLeft(-exp);
        return new BigInteger[] { num, den };
    }
}
