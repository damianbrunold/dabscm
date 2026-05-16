using System.Numerics;
using System.Text;

namespace scheme;

public class Complex : IEquatable<Complex>
{
    public readonly object Real;  // long, BigInteger, Rational, or double
    public readonly object Imag;  // long, BigInteger, Rational, or double

    internal Complex(object real, object imag)
    {
        Real = real;
        Imag = imag;
    }

    /// <summary>
    /// Creates a complex number, collapsing to a real if imaginary part is zero.
    /// Normalizes exactness: if either part is inexact, both become inexact.
    /// </summary>
    public static object Create(object real, object imag)
    {
        // Collapse to real only if imaginary part is EXACT zero.
        // Inexact 0.0 is preserved to maintain complex identity per R7RS.
        if (IsExactZero(imag))
        {
            return real;
        }

        bool realExact = IsExact(real);
        bool imagExact = IsExact(imag);

        if (realExact != imagExact)
        {
            if (realExact) real = ToInexact(real);
            else imag = ToInexact(imag);
        }

        return new Complex(real, imag);
    }

    private static bool IsExactZero(object v)
    {
        if (v is long l) return l == 0;
        if (v is System.Numerics.BigInteger bi) return bi.IsZero;
        return false;
    }

    // --- Part type helpers ---

    internal static bool IsExact(object v)
        => v is long || v is BigInteger || v is Rational;

    private static bool IsZero(object v)
    {
        if (v is long l) return l == 0;
        if (v is double d) return d == 0.0;
        if (v is BigInteger bi) return bi.IsZero;
        return false;
    }

    private static bool IsPartNegative(object v)
    {
        if (v is long l) return l < 0;
        if (v is double d) return d < 0.0;
        if (v is BigInteger bi) return bi.Sign < 0;
        if (v is Rational r) return IsPartNegative(r.Numerator);
        return false;
    }

    internal static object ToInexact(object v)
    {
        if (v is double) return v;
        if (v is long l) return (double)l;
        if (v is BigInteger bi) return (double)bi;
        if (v is Rational r) return r.ToDouble();
        return 0.0;
    }

    internal static object ToExact(object v)
    {
        if (v is long || v is BigInteger || v is Rational) return v;
        if (v is double d)
        {
            if (double.IsNaN(d) || double.IsInfinity(d))
                throw new SchemeError("exact: no exact equivalent for ~s", d);
            if (d == Math.Floor(d) && !double.IsInfinity(d))
            {
                try { return checked((long)d); }
                catch { return new BigInteger(d); }
            }
            // Use continued fractions for non-integral doubles
            return DoubleToExact(d);
        }
        return v;
    }

    private static object DoubleToExact(double d)
    {
        // Convert double to exact rational via continued fraction
        if (d == 0.0) return 0L;
        bool neg = d < 0;
        if (neg) d = -d;
        long bits = BitConverter.DoubleToInt64Bits(d);
        int exp = (int)((bits >> 52) & 0x7FF) - 1023 - 52;
        long mantissa = (bits & 0xFFFFFFFFFFFFF) | (1L << 52);
        BigInteger num = mantissa;
        BigInteger den = BigInteger.One;
        if (exp >= 0) { num <<= exp; }
        else { den <<= -exp; }
        BigInteger g = BigInteger.GreatestCommonDivisor(num, den);
        num /= g;
        den /= g;
        if (neg) num = -num;
        if (den == BigInteger.One)
            return IntegerMath.Normalize(num);
        return Rational.Create(IntegerMath.Normalize(num), IntegerMath.Normalize(den));
    }

    // --- Part arithmetic ---

    internal static object PartAdd(object a, object b)
    {
        if (a is long la && b is long lb)
        {
            try { checked { return la + lb; } }
            catch (OverflowException) { return (BigInteger)la + lb; }
        }
        if (Value.IsInteger(a) && Value.IsInteger(b)) return IntegerMath.GenericAdd(a, b);
        if (a is double || b is double) return PartToDouble(a) + PartToDouble(b);
        return Rational.Add(a, b);
    }

    internal static object PartSub(object a, object b)
    {
        if (a is long la && b is long lb)
        {
            try { checked { return la - lb; } }
            catch (OverflowException) { return (BigInteger)la - lb; }
        }
        if (Value.IsInteger(a) && Value.IsInteger(b)) return IntegerMath.GenericSub(a, b);
        if (a is double || b is double) return PartToDouble(a) - PartToDouble(b);
        return Rational.Sub(a, b);
    }

    internal static object PartMul(object a, object b)
    {
        if (a is long la && b is long lb)
        {
            try { checked { return la * lb; } }
            catch (OverflowException) { return (BigInteger)la * lb; }
        }
        if (Value.IsInteger(a) && Value.IsInteger(b)) return IntegerMath.GenericMul(a, b);
        if (a is double || b is double) return PartToDouble(a) * PartToDouble(b);
        return Rational.Mul(a, b);
    }

    internal static object PartDiv(object a, object b)
    {
        if (a is double || b is double) return PartToDouble(a) / PartToDouble(b);
        return Rational.Div(a, b);
    }

    internal static object PartNegate(object a)
    {
        if (a is long l) return IntegerMath.Negate(l);
        if (a is BigInteger) return IntegerMath.GenericNegate(a);
        if (a is double d) return -d;
        return Rational.Sub(0L, a);
    }

    internal static double PartToDouble(object v)
    {
        if (v is double d) return d;
        if (v is long l) return (double)l;
        if (Value.IsBigInteger(v)) return IntegerMath.ToDouble(v);
        if (v is Rational r) return r.ToDouble();
        return 0.0;
    }

    // --- Complex arithmetic ---

    private static void ExtractParts(object v, out object real, out object imag)
    {
        if (v is Complex c) { real = c.Real; imag = c.Imag; return; }
        real = v;
        imag = IsExact(v) ? (object)0L : 0.0;
    }

    public static object Add(object a, object b)
    {
        ExtractParts(a, out object ar, out object ai);
        ExtractParts(b, out object br, out object bi);
        return Create(PartAdd(ar, br), PartAdd(ai, bi));
    }

    public static object Sub(object a, object b)
    {
        ExtractParts(a, out object ar, out object ai);
        ExtractParts(b, out object br, out object bi);
        return Create(PartSub(ar, br), PartSub(ai, bi));
    }

    public static object Negate(object a)
    {
        if (a is Complex c) return Create(PartNegate(c.Real), PartNegate(c.Imag));
        return PartNegate(a);
    }

    public static object Mul(object a, object b)
    {
        ExtractParts(a, out object ar, out object ai);
        ExtractParts(b, out object br, out object bi);
        // (ar + ai*i)(br + bi*i) = (ar*br - ai*bi) + (ar*bi + ai*br)*i
        object realPart = PartSub(PartMul(ar, br), PartMul(ai, bi));
        object imagPart = PartAdd(PartMul(ar, bi), PartMul(ai, br));
        return Create(realPart, imagPart);
    }

    public static object Div(object a, object b)
    {
        ExtractParts(a, out object ar, out object ai);
        ExtractParts(b, out object br, out object bi);
        // (ar + ai*i) / (br + bi*i)
        // = ((ar*br + ai*bi) + (ai*br - ar*bi)*i) / (br^2 + bi^2)
        object denom = PartAdd(PartMul(br, br), PartMul(bi, bi));
        if (IsZero(denom)) throw new SchemeError("/: Division by zero");
        object realPart = PartDiv(PartAdd(PartMul(ar, br), PartMul(ai, bi)), denom);
        object imagPart = PartDiv(PartSub(PartMul(ai, br), PartMul(ar, bi)), denom);
        return Create(realPart, imagPart);
    }

    // --- Magnitude and angle ---

    public static double Magnitude(Complex c)
    {
        double r = PartToDouble(c.Real);
        double i = PartToDouble(c.Imag);
        return Math.Sqrt(r * r + i * i);
    }

    public static double Angle(Complex c)
    {
        double r = PartToDouble(c.Real);
        double i = PartToDouble(c.Imag);
        return Math.Atan2(i, r);
    }

    // --- Equality ---

    public bool Equals(Complex? other)
    {
        if (other is null) return false;
        return PartEquals(Real, other.Real) && PartEquals(Imag, other.Imag);
    }

    public override bool Equals(object? obj) => obj is Complex c && Equals(c);

    public override int GetHashCode() => HashCode.Combine(Real, Imag);

    /// <summary>
    /// Strict equality: same type and value (for eqv?).
    /// </summary>
    private static bool PartEquals(object a, object b)
    {
        if (a is long la && b is long lb) return la == lb;
        if (Value.IsInteger(a) && Value.IsInteger(b)) return IntegerMath.GenericEquals(a, b);
        if (a is double da && b is double db) return da == db;
        if (a is Rational ra && b is Rational rb) return ra.Equals(rb);
        return false;
    }

    /// <summary>
    /// Numeric equality across exactness (for =).
    /// </summary>
    public static bool NumericEquals(object a, object b)
    {
        ExtractParts(a, out object ar, out object ai);
        ExtractParts(b, out object br, out object bi);
        return NumericPartEquals(ar, br) && NumericPartEquals(ai, bi);
    }

    private static bool NumericPartEquals(object a, object b)
    {
        if (a is long la && b is long lb) return la == lb;
        if (Value.IsInteger(a) && Value.IsInteger(b)) return IntegerMath.GenericEquals(a, b);
        if (a is double da && b is double db) return da == db;
        if (a is Rational ra && b is Rational rb) return ra.Equals(rb);
        // Mixed exact/inexact
        return Primitive.MixedNumericEquals(a, b);
    }

    // --- String representation ---

    public override string ToString()
    {
        var sb = new StringBuilder();
        AppendPart(sb, Real);

        bool negImag = IsPartNegative(Imag);
        sb.Append(negImag ? '-' : '+');
        AppendAbsImag(sb, Imag);
        sb.Append('i');

        return sb.ToString();
    }

    private static void AppendPart(StringBuilder sb, object v)
    {
        if (v is double d) sb.Append(Value.FormatDouble(d));
        else if (v is Rational r) sb.Append(r.ToString());
        else sb.Append(v);
    }

    private static void AppendAbsImag(StringBuilder sb, object v)
    {
        if (v is double d)
        {
            if (double.IsNaN(d)) sb.Append("nan.0");
            else if (double.IsInfinity(d)) sb.Append("inf.0");
            else sb.Append(Value.FormatDouble(Math.Abs(d)));
        }
        else
        {
            object abs = PartAbs(v);
            if (abs is Rational r) sb.Append(r.ToString());
            else sb.Append(abs);
        }
    }

    private static object PartAbs(object v)
    {
        if (v is long l) return l >= 0 ? (object)l : IntegerMath.Negate(l);
        if (v is BigInteger) return IntegerMath.GenericAbs(v);
        if (v is Rational r)
        {
            if (IntegerMath.IsNegative(r.Numerator))
                return Rational.Create(IntegerMath.GenericNegate(r.Numerator), r.Denominator);
            return r;
        }
        return v;
    }
}
