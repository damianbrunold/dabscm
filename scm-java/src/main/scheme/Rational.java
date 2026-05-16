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
        return (Rational) v;
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

    public double toDouble() {
        return IntegerMath.toDouble(numerator) / IntegerMath.toDouble(denominator);
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
