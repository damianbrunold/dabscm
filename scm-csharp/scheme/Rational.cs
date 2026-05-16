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
        return (Rational)v;
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

    public double ToDouble()
    {
        return IntegerMath.ToDouble(Numerator) / IntegerMath.ToDouble(Denominator);
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
