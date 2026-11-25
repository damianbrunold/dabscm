using System.Numerics;

namespace scheme;

/// <summary>
/// exp, log, sqrt, expt and the trigonometric functions on the whole numeric
/// tower (R7RS 6.2.6): complex arguments, and real arguments outside the real
/// domain, give the principal complex value. Results are inexact except
/// where noted (sqrt of an exact square, expt with an exact integer power).
/// A result whose imaginary part is an exact zero is real (Complex.Create).
/// </summary>
public static class ComplexMath
{
    // A real number as a double; anything else (a non-real complex number,
    // a non-number) is a wrong argument type, with the value as irritant.
    public static double Real(object v)
    {
        if (v is double d) return d;
        if (v is long l) return l;
        if (v is BigInteger) return IntegerMath.ToDouble(v);
        if (v is Rational r) return r.ToDouble();
        throw new WrongTypeException(v, "real number");
    }

    private static void Parts(object z, out double re, out double im)
    {
        if (z is Complex c) { re = Complex.PartToDouble(c.Real); im = Complex.PartToDouble(c.Imag); }
        else { re = Real(z); im = 0.0; }
    }

    private static object Make(double re, double im) => Complex.Create(re, im);

    // --- exp and log ---

    public static object Exp(object z)
    {
        if (z is not Complex) return Math.Exp(Real(z));
        Parts(z, out double x, out double y);
        double ex = Math.Exp(x);
        // a zero imaginary part stays (exp +inf.0+0.0i is +inf.0+0.0i, not NaN)
        if (y == 0.0) return Make(ex, y);
        return Make(ex * Math.Cos(y), ex * Math.Sin(y));
    }

    public static object Log(object z)
    {
        if (z is not Complex)
        {
            double x = Real(z);
            // (log 0) and (log 0.0) are -inf.0; a negative x (-0.0 too): ln|x| + pi i
            if (x > 0.0 || double.IsNaN(x) || (x == 0.0 && !double.IsNegative(x))) return Math.Log(x);
            return Make(Math.Log(-x), Math.PI);
        }
        Parts(z, out double re, out double im);
        return Make(Math.Log(double.Hypot(re, im)), Math.Atan2(im, re));
    }

    // (log z b) = (log z) / (log b)
    public static object Log(object z, object b)
    {
        object lz = Log(z), lb = Log(b);
        if (lz is double dz && lb is double db) return dz / db;
        return Complex.Div(lz, lb);
    }

    // --- sqrt ---

    public static object Sqrt(object z)
    {
        if (Value.IsInteger(z))
        {
            if (IntegerMath.IsNegative(z)) return Complex.Create(0.0, InexactSqrt(IntegerMath.GenericNegate(z)));
            object s = ExactSqrt(z);
            if (s != null) return s;
            return InexactSqrt(z);
        }
        if (z is Rational r)
        {
            if (IntegerMath.IsNegative(r.Numerator)) return Complex.Create(0L, Math.Sqrt(-r.ToDouble()));
            object? sn = ExactSqrt(r.Numerator), sd = ExactSqrt(r.Denominator);
            if (sn != null && sd != null) return Rational.Create(sn, sd);
            return Math.Sqrt(r.ToDouble());
        }
        if (z is Complex)
        {
            Parts(z, out double x, out double y);
            CSqrt(x, y, out double re, out double im);
            return new Complex(re, im);
        }
        double d = Real(z);
        if (d < 0) return Complex.Create(0.0, Math.Sqrt(-d));
        return Math.Sqrt(d);
    }

    // The exact square root of a non-negative exact integer that is a
    // perfect square, else null.
    private static object? ExactSqrt(object n)
    {
        BigInteger b = IntegerMath.ToBigInteger(n);
        BigInteger s = IntegerSqrt(b);
        return s * s == b ? IntegerMath.Normalize(s) : null;
    }

    // floor(sqrt(n)) for n >= 0
    public static BigInteger IntegerSqrt(BigInteger n)
    {
        if (n.Sign <= 0) return BigInteger.Zero;
        if (n < (BigInteger.One << 52))
        {
            long s = (long)Math.Sqrt((double)n);
            while (s * s > (long)n) s--;
            while ((s + 1) * (s + 1) <= (long)n) s++;
            return s;
        }
        // Newton's method from a power of two above the root
        BigInteger x = BigInteger.One << (int)((n.GetBitLength() + 1) / 2);
        while (true)
        {
            BigInteger y = (x + n / x) >> 1;
            if (y >= x) return x;
            x = y;
        }
    }

    // sqrt of a non-negative exact integer that is no perfect square
    private static double InexactSqrt(object n)
    {
        double r = Math.Sqrt(IntegerMath.ToDouble(n));
        if (double.IsFinite(r)) return r;
        // beyond the double range: the integer root is as good as it gets
        return IntegerMath.ToDouble(IntegerSqrt(IntegerMath.ToBigInteger(n)));
    }

    // --- expt ---

    public static object Expt(object z1, object z2)
    {
        bool z1Exact = IsExactNumber(z1), z2Exact = IsExactNumber(z2);
        if (Value.IsInteger(z2))
        {
            // exact integer power: repeated squaring, exact stays exact
            if (z1Exact || z1 is Complex) return ExptInteger(z1, z2);
            double a = Real(z1);
            return Math.Pow(a, IntegerMath.ToDouble(z2));
        }
        if (IsZeroNumber(z1))
        {
            if (IsZeroNumber(z2)) return z1Exact && z2Exact ? (object)1L : 1.0;
            Parts(z2, out double re2, out _);
            if (re2 > 0.0) return z1Exact && z2Exact ? (object)0L : 0.0;
            throw new SchemeError("/: Division by zero");
        }
        if (z1 is not Complex && z2 is not Complex)
        {
            double a = Real(z1), b = Real(z2);
            if (b == 0.0) return 1.0;
            // a negative base to a non-integer power: the principal complex value
            if (a < 0 && b != Math.Round(b) && !double.IsInfinity(b)) return Pow(a, 0.0, b, 0.0);
            return Math.Pow(a, b);
        }
        // (exp z) is (expt E z)
        if (z1 is double e && e == Math.E) return Exp(z2);
        Parts(z1, out double ar, out double ai);
        Parts(z2, out double br, out double bi);
        return Pow(ar, ai, br, bi);
    }

    // z1^z2 = exp(z2 log z1), in polar form: |z1|^x2 e^(-y2 angle z1) at the
    // angle x2 angle z1 + y2 ln|z1| (so (expt -1 0.5) is
    // 6.123233995736766e-17+1.0i, the magnitude Math.Pow(1.0, 0.5) = 1.0)
    private static object Pow(double ar, double ai, double br, double bi)
    {
        double r = double.Hypot(ar, ai), at = Math.Atan2(ai, ar);
        double len = Math.Pow(r, br), phase = at * br;
        if (bi != 0.0)
        {
            len /= Math.Exp(at * bi);
            phase += bi * Math.Log(r);
        }
        return new Complex(len * Math.Cos(phase), len * Math.Sin(phase));
    }

    private static object ExptInteger(object z, object n)
    {
        if (IntegerMath.IsZero(n)) return IsExactNumber(z) ? (object)1L : 1.0;
        bool negative = IntegerMath.IsNegative(n);
        if (Value.IsInteger(z) && !negative && n is long ln) return IntegerMath.Expt(z, ln);
        if (negative && IsExactNumber(z) && IsZeroNumber(z)) throw new SchemeError("/: Division by zero");
        if (n is not long && IsExactNumber(z) && !IsUnit(z))
            throw new SchemeError("expt: exponent too large");
        BigInteger e = BigInteger.Abs(IntegerMath.ToBigInteger(n));
        object result = 1L, square = z;
        while (true)
        {
            if (!e.IsEven) result = Complex.Mul(result, square);
            e >>= 1;
            if (e.IsZero) break;
            square = Complex.Mul(square, square);
        }
        if (negative) result = Reciprocal(result);
        return result;
    }

    // 1 or -1 (exact), whose powers stay small
    private static bool IsUnit(object z) => z is long l && (l == 1 || l == -1);

    private static object Reciprocal(object z)
    {
        if (z is double d) return 1.0 / d;
        return Complex.Div(1L, z);
    }

    private static bool IsExactNumber(object v)
        => v is long || v is BigInteger || v is Rational || (v is Complex c && Complex.IsExact(c.Real));

    private static bool IsZeroNumber(object v)
    {
        if (v is Complex c) return IsZeroPart(c.Real) && IsZeroPart(c.Imag);
        return IsZeroPart(v);
    }

    private static bool IsZeroPart(object v) => v switch
    {
        long l => l == 0,
        double d => d == 0.0,
        _ => false,   // a BigInteger or Rational is never zero
    };

    // --- trigonometric functions ---

    public static object Sin(object z)
    {
        if (z is not Complex) return Math.Sin(Real(z));
        Parts(z, out double x, out double y);
        return Make(Math.Sin(x) * Math.Cosh(y), Math.Cos(x) * Math.Sinh(y));
    }

    public static object Cos(object z)
    {
        if (z is not Complex) return Math.Cos(Real(z));
        Parts(z, out double x, out double y);
        return Make(Math.Cos(x) * Math.Cosh(y), -(Math.Sin(x) * Math.Sinh(y)));
    }

    public static object Tan(object z)
    {
        if (z is not Complex) return Math.Tan(Real(z));
        Parts(z, out double x, out double y);
        double sr = Math.Sin(x) * Math.Cosh(y), si = Math.Cos(x) * Math.Sinh(y);
        double cr = Math.Cos(x) * Math.Cosh(y), ci = -(Math.Sin(x) * Math.Sinh(y));
        double d = cr * cr + ci * ci;
        return new Complex((sr * cr + si * ci) / d, (si * cr - sr * ci) / d);
    }

    // asin z = -i log(iz + sqrt(1 - z^2)), on doubles; the zero imaginary
    // parts as the exact 1 gives them (0 - 0.0 = 0.0), so that (asin 2) is
    // 1.57...-1.31...i
    private static void CAsin(double x, double y, out double re, out double im)
    {
        double z2r = x * x - y * y, z2i = x * y + y * x;
        CSqrt(1.0 - z2r, 0.0 - z2i, out double sr, out double si);
        double lr = Math.Log(double.Hypot(sr - y, si + x)), li = Math.Atan2(si + x, sr - y);
        re = li;
        im = -lr;
    }

    // the principal square root; the imaginary part is negative only for
    // y < 0 (-0.0 counts as positive: (sqrt -1.0-0.0i) is +i, as chibi's
    // R7RS tests expect)
    private static void CSqrt(double x, double y, out double re, out double im)
    {
        double r = double.Hypot(x, y);
        double i = Math.Sqrt((r - x) / 2);
        re = Math.Sqrt((r + x) / 2);
        im = y < 0 ? -i : i;
    }

    public static object Asin(object z)
    {
        if (z is not Complex)
        {
            double x = Real(z);
            if (!(x < -1.0 || x > 1.0)) return Math.Asin(x);
        }
        Parts(z, out double zr, out double zi);
        CAsin(zr, zi, out double re, out double im);
        return new Complex(re, im);
    }

    // acos z = pi/2 - asin z
    public static object Acos(object z)
    {
        if (z is not Complex)
        {
            double x = Real(z);
            if (!(x < -1.0 || x > 1.0)) return Math.Acos(x);
        }
        Parts(z, out double zr, out double zi);
        CAsin(zr, zi, out double re, out double im);
        return new Complex(Math.PI / 2 - re, -im);
    }

    // atan z = (log(1 + iz) - log(1 - iz)) / 2i
    public static object Atan(object z)
    {
        if (z is not Complex) return Math.Atan(Real(z));
        Parts(z, out double x, out double y);
        double ar = Math.Log(double.Hypot(1.0 - y, 0.0 + x)), ai = Math.Atan2(0.0 + x, 1.0 - y);
        double br = Math.Log(double.Hypot(1.0 + y, 0.0 - x)), bi = Math.Atan2(0.0 - x, 1.0 + y);
        double dr = ar - br, di = ai - bi;
        // (dr + di i) / 2i = di/2 - (dr/2) i
        return new Complex(di / 2, -dr / 2);
    }
}
