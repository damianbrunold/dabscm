using System.Numerics;

namespace scheme;

public class Rational : IEquatable<Rational>, IComparable<Rational>
{
    public readonly object Numerator;   // long or BigInteger
    public readonly object Denominator; // long or BigInteger

    private Rational(object n, object d)
    {
        Numerator = n;
        Denominator = d;
    }

    // Fast path: both long
    public static object Create(long n, long d)
    {
        if (d == 0) throw new SchemeError("rational: division by zero");
        if (n == 0) return 0L;
        long sign = d < 0 ? -1 : 1;
        long absN = Math.Abs(n), absD = Math.Abs(d);
        long g = LongGcd(absN, absD);
        long rn = sign * n / g;
        long rd = Math.Abs(d) / g;
        return rd == 1 ? (object)rn : new Rational(rn, rd);
    }

    // Generic path: handles BigInteger numerator/denominator
    public static object Create(object n, object d)
    {
        if (n is long nl && d is long dl) return Create(nl, dl);
        if (IntegerMath.IsZero(d)) throw new SchemeError("rational: division by zero");
        if (IntegerMath.IsZero(n)) return 0L;
        // Normalize sign: denominator always positive
        if (IntegerMath.IsNegative(d))
        {
            n = IntegerMath.GenericNegate(n);
            d = IntegerMath.GenericNegate(d);
        }
        object g = IntegerMath.Gcd(n, d);
        object rn = IntegerMath.GenericQuotient(n, g);
        object rd = IntegerMath.GenericQuotient(d, g);
        if (rn is long rnl && rd is long rdl)
        {
            return rdl == 1 ? (object)rnl : new Rational(rnl, rdl);
        }
        // Check if denominator is 1
        if (IntegerMath.GenericEquals(rd, 1L)) return rn;
        return new Rational(rn, rd);
    }

    public static Rational Lift(object v)
    {
        if (v is long l) return new Rational(l, 1L);
        if (v is BigInteger) return new Rational(v, 1L);
        if (v is Rational r) return r;
        throw new WrongTypeException(v, "number");
    }

    private static long LongGcd(long a, long b)
    {
        while (b != 0) { long t = b; b = a % b; a = t; }
        return a == 0 ? 1 : a;
    }

    public static object Add(object a, object b)
    {
        Rational ra = Lift(a), rb = Lift(b);
        // num = ra.Num * rb.Den + rb.Num * ra.Den, den = ra.Den * rb.Den
        object num = IntegerMath.GenericAdd(
            IntegerMath.GenericMul(ra.Numerator, rb.Denominator),
            IntegerMath.GenericMul(rb.Numerator, ra.Denominator));
        object den = IntegerMath.GenericMul(ra.Denominator, rb.Denominator);
        return Create(num, den);
    }

    public static object Sub(object a, object b)
    {
        Rational ra = Lift(a), rb = Lift(b);
        object num = IntegerMath.GenericSub(
            IntegerMath.GenericMul(ra.Numerator, rb.Denominator),
            IntegerMath.GenericMul(rb.Numerator, ra.Denominator));
        object den = IntegerMath.GenericMul(ra.Denominator, rb.Denominator);
        return Create(num, den);
    }

    public static object Mul(object a, object b)
    {
        Rational ra = Lift(a), rb = Lift(b);
        object num = IntegerMath.GenericMul(ra.Numerator, rb.Numerator);
        object den = IntegerMath.GenericMul(ra.Denominator, rb.Denominator);
        return Create(num, den);
    }

    public static object Div(object a, object b)
    {
        Rational ra = Lift(a), rb = Lift(b);
        if (IntegerMath.IsZero(rb.Numerator)) throw new SchemeError("/: Division by zero");
        object num = IntegerMath.GenericMul(ra.Numerator, rb.Denominator);
        object den = IntegerMath.GenericMul(ra.Denominator, rb.Numerator);
        return Create(num, den);
    }

    // Correctly rounded (to nearest, ties to even), also when numerator or
    // denominator is beyond the double range or the result is subnormal.
    public double ToDouble()
    {
        const long exactLimit = 1L << 53;
        if (Numerator is long n && Denominator is long d && n >= -exactLimit && n <= exactLimit && d <= exactLimit)
            return (double)n / (double)d;   // exact operands, so the division rounds correctly
        BigInteger num = IntegerMath.ToBigInteger(Numerator), den = IntegerMath.ToBigInteger(Denominator);
        bool negative = num.Sign < 0;
        if (negative) num = -num;
        // E = floor(log2(num/den)) is e or e - 1
        long e = num.GetBitLength() - den.GetBitLength();
        bool atLeast = e >= 0 ? num >= den << (int)e : num << (int)-e >= den;
        long E = atLeast ? e : e - 1;
        if (E > 1023) return negative ? double.NegativeInfinity : double.PositiveInfinity;
        // q = num/den in units of the result's last place, rounded half to even
        int lsb = (int)Math.Max(E - 52, -1074);
        BigInteger a = lsb < 0 ? num << -lsb : num, b = lsb > 0 ? den << lsb : den;
        BigInteger q = BigInteger.DivRem(a, b, out BigInteger r);
        int half = (r << 1).CompareTo(b);
        if (half > 0 || (half == 0 && !q.IsEven)) q += 1;
        double result = Math.ScaleB((double)q, lsb);   // q <= 2^53, so exact unless it overflows
        return negative ? -result : result;
    }

    // floor, ceiling, truncate and round (half to even), exactly; the
    // denominator is positive.
    public object Floor()
    {
        object q = IntegerMath.GenericQuotient(Numerator, Denominator);
        return IntegerMath.IsNegative(Numerator) ? IntegerMath.GenericSub(q, 1L) : q;
    }

    public object Ceiling()
    {
        object q = IntegerMath.GenericQuotient(Numerator, Denominator);
        return IntegerMath.IsNegative(Numerator) ? q : IntegerMath.GenericAdd(q, 1L);
    }

    public object Truncate() => IntegerMath.GenericQuotient(Numerator, Denominator);

    public object Round()
    {
        object fl = Floor();
        object twiceFrac = IntegerMath.GenericMul(IntegerMath.GenericModulo(Numerator, Denominator), 2L);
        int c = IntegerMath.Compare(twiceFrac, Denominator);
        if (c < 0) return fl;
        if (c > 0) return IntegerMath.GenericAdd(fl, 1L);
        return IntegerMath.IsZero(IntegerMath.GenericModulo(fl, 2L)) ? fl : IntegerMath.GenericAdd(fl, 1L);
    }

    public override string ToString() => $"{Numerator}/{Denominator}";

    public bool Equals(Rational? other)
    {
        if (other is null) return false;
        return IntegerMath.GenericEquals(Numerator, other.Numerator) &&
               IntegerMath.GenericEquals(Denominator, other.Denominator);
    }

    public override bool Equals(object? obj) => obj is Rational r && Equals(r);

    public override int GetHashCode()
    {
        return HashCode.Combine(Numerator, Denominator);
    }

    public int CompareTo(Rational? other)
    {
        if (other is null) return 1;
        // Both denominators are positive after Create normalisation
        object lhs = IntegerMath.GenericMul(Numerator, other.Denominator);
        object rhs = IntegerMath.GenericMul(other.Numerator, Denominator);
        return IntegerMath.Compare(lhs, rhs);
    }
}
