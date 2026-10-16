package scheme;

import java.math.BigInteger;

public final class Rational implements Comparable<Rational> {
    public final Object numerator;   // Long or BigInteger
    public final Object denominator; // Long or BigInteger

    private Rational(Object n, Object d) {
        this.numerator = n;
        this.denominator = d;
    }

    // Fast path: both long
    public static Object create(long n, long d) {
        if (d == 0) throw new SchemeError("rational: division by zero");
        if (n == 0) return 0L;
        long sign = d < 0 ? -1 : 1;
        long absN = Math.abs(n), absD = Math.abs(d);
        long g = longGcd(absN, absD);
        long rn = sign * n / g;
        long rd = Math.abs(d) / g;
        return rd == 1 ? (Object) rn : new Rational(rn, rd);
    }

    // Generic path: handles BigInteger numerator/denominator
    public static Object create(Object n, Object d) {
        if (n instanceof Long && d instanceof Long) return create((long)(Long) n, (long)(Long) d);
        if (IntegerMath.isZero(d)) throw new SchemeError("rational: division by zero");
        if (IntegerMath.isZero(n)) return 0L;
        // Normalize sign: denominator always positive
        if (IntegerMath.isNegative(d)) {
            n = IntegerMath.genericNegate(n);
            d = IntegerMath.genericNegate(d);
        }
        Object g = IntegerMath.gcd(n, d);
        Object rn = IntegerMath.genericQuotient(n, g);
        Object rd = IntegerMath.genericQuotient(d, g);
        if (rn instanceof Long && rd instanceof Long) {
            long rdl = (long)(Long) rd;
            return rdl == 1 ? rn : new Rational(rn, rd);
        }
        // Check if denominator is 1
        if (IntegerMath.genericEquals(rd, 1L)) return rn;
        return new Rational(rn, rd);
    }

    public static Rational lift(Object v) {
        if (v instanceof Long) return new Rational(v, 1L);
        if (v instanceof BigInteger) return new Rational(v, 1L);
        if (v instanceof Rational) return (Rational) v;
        throw new WrongTypeException(v, "number");
    }

    private static long longGcd(long a, long b) {
        while (b != 0) { long t = b; b = a % b; a = t; }
        return a == 0 ? 1 : a;
    }

    public static Object add(Object a, Object b) {
        Rational ra = lift(a), rb = lift(b);
        Object num = IntegerMath.genericAdd(
            IntegerMath.genericMul(ra.numerator, rb.denominator),
            IntegerMath.genericMul(rb.numerator, ra.denominator));
        Object den = IntegerMath.genericMul(ra.denominator, rb.denominator);
        return create(num, den);
    }

    public static Object sub(Object a, Object b) {
        Rational ra = lift(a), rb = lift(b);
        Object num = IntegerMath.genericSub(
            IntegerMath.genericMul(ra.numerator, rb.denominator),
            IntegerMath.genericMul(rb.numerator, ra.denominator));
        Object den = IntegerMath.genericMul(ra.denominator, rb.denominator);
        return create(num, den);
    }

    public static Object mul(Object a, Object b) {
        Rational ra = lift(a), rb = lift(b);
        Object num = IntegerMath.genericMul(ra.numerator, rb.numerator);
        Object den = IntegerMath.genericMul(ra.denominator, rb.denominator);
        return create(num, den);
    }

    public static Object div(Object a, Object b) {
        Rational ra = lift(a), rb = lift(b);
        if (IntegerMath.isZero(rb.numerator)) throw new SchemeError("/: Division by zero");
        Object num = IntegerMath.genericMul(ra.numerator, rb.denominator);
        Object den = IntegerMath.genericMul(ra.denominator, rb.numerator);
        return create(num, den);
    }

    // Correctly rounded (to nearest, ties to even), also when numerator or
    // denominator is beyond the double range or the result is subnormal.
    public double toDouble() {
        final long exactLimit = 1L << 53;
        if (numerator instanceof Long && denominator instanceof Long) {
            long n = (Long) numerator, d = (Long) denominator;
            if (n >= -exactLimit && n <= exactLimit && d <= exactLimit)
                return (double) n / (double) d;   // exact operands, so the division rounds correctly
        }
        BigInteger num = IntegerMath.toBigInteger(numerator), den = IntegerMath.toBigInteger(denominator);
        boolean negative = num.signum() < 0;
        if (negative) num = num.negate();
        // E = floor(log2(num/den)) is e or e - 1
        long e = (long) num.bitLength() - den.bitLength();
        boolean atLeast = e >= 0 ? num.compareTo(den.shiftLeft((int) e)) >= 0
                                 : num.shiftLeft((int) -e).compareTo(den) >= 0;
        long bigE = atLeast ? e : e - 1;
        if (bigE > 1023) return negative ? Double.NEGATIVE_INFINITY : Double.POSITIVE_INFINITY;
        // q = num/den in units of the result's last place, rounded half to even
        int lsb = (int) Math.max(bigE - 52, -1074);
        BigInteger a = lsb < 0 ? num.shiftLeft(-lsb) : num, b = lsb > 0 ? den.shiftLeft(lsb) : den;
        BigInteger[] qr = a.divideAndRemainder(b);
        BigInteger q = qr[0];
        int half = qr[1].shiftLeft(1).compareTo(b);
        if (half > 0 || (half == 0 && q.testBit(0))) q = q.add(BigInteger.ONE);
        double result = Math.scalb(q.doubleValue(), lsb);   // q <= 2^53, so exact unless it overflows
        return negative ? -result : result;
    }

    // floor, ceiling, truncate and round (half to even), exactly; the
    // denominator is positive.
    public Object floor() {
        Object q = IntegerMath.genericQuotient(numerator, denominator);
        return IntegerMath.isNegative(numerator) ? IntegerMath.genericSub(q, 1L) : q;
    }

    public Object ceiling() {
        Object q = IntegerMath.genericQuotient(numerator, denominator);
        return IntegerMath.isNegative(numerator) ? q : IntegerMath.genericAdd(q, 1L);
    }

    public Object truncate() {
        return IntegerMath.genericQuotient(numerator, denominator);
    }

    public Object round() {
        Object fl = floor();
        Object twiceFrac = IntegerMath.genericMul(IntegerMath.genericModulo(numerator, denominator), 2L);
        int c = IntegerMath.compare(twiceFrac, denominator);
        if (c < 0) return fl;
        if (c > 0) return IntegerMath.genericAdd(fl, 1L);
        return IntegerMath.isZero(IntegerMath.genericModulo(fl, 2L)) ? fl : IntegerMath.genericAdd(fl, 1L);
    }

    @Override
    public String toString() {
        return numerator + "/" + denominator;
    }

    @Override
    public boolean equals(Object obj) {
        if (!(obj instanceof Rational)) return false;
        Rational other = (Rational) obj;
        return IntegerMath.genericEquals(numerator, other.numerator) &&
               IntegerMath.genericEquals(denominator, other.denominator);
    }

    @Override
    public int hashCode() {
        return numerator.hashCode() * 31 + denominator.hashCode();
    }

    @Override
    public int compareTo(Rational other) {
        Object lhs = IntegerMath.genericMul(numerator, other.denominator);
        Object rhs = IntegerMath.genericMul(other.numerator, denominator);
        return IntegerMath.compare(lhs, rhs);
    }
}
