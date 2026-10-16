namespace scheme;

public abstract class Primitive
{
    public abstract string Name();
    public abstract string Info();
    public abstract object Apply(SourcePos? pos, object[] arguments);

    protected void CheckArgs(SourcePos? pos, object[] arguments, int minArgs, int maxArgs)
    {
        if (minArgs == maxArgs && arguments.Length != minArgs)
        {
            throw new SchemeError(
                pos,
                "~s needs ~s arguments, but got ~s",
                Name(), minArgs, arguments.Length
            );
        }
        if (maxArgs == -1 && arguments.Length < minArgs)
        {
            throw new SchemeError(
                pos,
                "~s needs at least ~s arguments, but got ~s",
                Name(), minArgs, arguments.Length
            );
        }
        if (maxArgs != -1 && (arguments.Length < minArgs || arguments.Length > maxArgs))
        {
            throw new SchemeError(
                pos,
                "~s needs between ~s and ~s arguments, but got ~s",
                Name(), minArgs, maxArgs, arguments.Length
            );
        }
    }
    
    public override string ToString()
    {
        return "#<p:" + Name() + ">";
    }

    protected double ToReal(object value)
    {
        if (value is long l) return (double)l;
        if (Value.IsBigInteger(value)) return IntegerMath.ToDouble(value);
        if (value is Rational r) return r.ToDouble();
        return (double)value;
    }

    protected bool AllIntegers(object[] args)
    {
        foreach (object arg in args)
        {
            if (!Value.IsInteger(arg))
            {
                return false;
            }
        }
        return true;
    }

    protected bool AllExactNums(object[] args)
    {
        foreach (object arg in args)
        {
            if (!Value.IsInteger(arg) && !Value.IsRational(arg))
                return false;
        }
        return true;
    }

    protected bool HasComplex(object[] args)
    {
        foreach (object arg in args)
        {
            if (arg is Complex)
                return true;
        }
        return false;
    }

    protected object ToIntegerIfPossible(object value)
    {
        if (Value.IsInteger(value)) return value;
        double val = ToReal(value);
        if (val == Math.Floor(val)) return (long) val;
        return value;
    }

    /// <summary>
    /// = for real numbers that are not both integers or both doubles.
    /// Exact numbers (integers, rationals) are compared exactly, a finite
    /// double against an exact number via its exact value. A non-number
    /// throws WrongTypeException ("wrong argument type" with the value).
    /// </summary>
    public static bool MixedNumericEquals(object a, object b)
    {
        if (a is double da) return b is double db ? da == db : DoubleExactCompare(da, b, true) == 0;
        if (b is double db2) return DoubleExactCompare(db2, a, true) == 0;
        CheckExact(a); CheckExact(b);
        return ExactCompare(a, b) == 0;
    }

    /// <summary>
    /// Ordering for real numbers that are not both integers or both doubles,
    /// exact like MixedNumericEquals. Returns -1 if a &lt; b, 1 if a &gt; b, 0 if
    /// equal and Unordered if one is NaN (then every comparison is false).
    /// </summary>
    public static int MixedNumericCompare(object a, object b)
    {
        if (a is double da) return b is double db ? DoubleCompare(da, db) : DoubleExactCompare(da, b, false);
        if (b is double db2) { int c = DoubleExactCompare(db2, a, false); return c == Unordered ? c : -c; }
        CheckExact(a); CheckExact(b);
        return ExactCompare(a, b);
    }

    public const int Unordered = 2;

    // <, >, <= and >= for operands MixedNumericCompare accepts.
    public static bool NumLess(object a, object b) => MixedNumericCompare(a, b) == -1;
    public static bool NumGreater(object a, object b) => MixedNumericCompare(a, b) == 1;
    public static bool NumLessEq(object a, object b) { int c = MixedNumericCompare(a, b); return c == -1 || c == 0; }
    public static bool NumGreaterEq(object a, object b) { int c = MixedNumericCompare(a, b); return c == 0 || c == 1; }

    private const long MaxExactDouble = 1L << 53;

    private static int DoubleCompare(double a, double b) => a < b ? -1 : a > b ? 1 : a == b ? 0 : Unordered;

    // Compares double d with exact x; for equality (forEquals), NaN and
    // infinities are unequal to everything (1), for ordering NaN is Unordered.
    private static int DoubleExactCompare(double d, object x, bool forEquals)
    {
        CheckExact(x);
        // Fast paths without allocation. A long within 2^53 is exact as a
        // double. n/d of longs within 2^53 is correctly rounded, and rounding
        // keeps the order, so a rounded value other than d orders like x.
        if (x is long l && l >= -MaxExactDouble && l <= MaxExactDouble)
            return forEquals ? (d == (double)l ? 0 : 1) : DoubleCompare(d, (double)l);
        if (x is Rational r && r.Numerator is long n && r.Denominator is long den
            && n >= -MaxExactDouble && n <= MaxExactDouble && den <= MaxExactDouble)
        {
            double xd = (double)n / (double)den;
            if (xd != d) return forEquals ? 1 : DoubleCompare(d, xd);
        }
        if (double.IsNaN(d)) return forEquals ? 1 : Unordered;
        if (double.IsInfinity(d)) return d > 0 ? 1 : -1;
        return ExactCompare(Complex.ToExact(d), x);
    }

    /// <summary>
    /// quotient, remainder and modulo with an inexact argument: computed
    /// exactly on the integer values, the result as a (correctly rounded)
    /// double. A non-integral argument is a wrong argument type.
    /// </summary>
    protected static double InexactIntegerOp(object a, object b, Func<object, object, object> op)
        => IntegerMath.ToDouble(op(ExactIntegerOf(a), ExactIntegerOf(b)));

    private static object ExactIntegerOf(object v)
    {
        if (Value.IsInteger(v)) return v;
        if (v is double d && double.IsFinite(d) && d == Math.Truncate(d)) return Complex.ToExact(d);
        throw new WrongTypeException(v, "integer");
    }

    private static void CheckExact(object v)
    {
        if (!(v is long || v is System.Numerics.BigInteger || v is Rational))
            throw new WrongTypeException(v, "number");
    }

    // Both exact; rational denominators are positive.
    private static int ExactCompare(object a, object b)
    {
        if (a is Rational ra)
        {
            if (b is Rational rb) return Math.Sign(ra.CompareTo(rb));
            return Math.Sign(IntegerMath.Compare(ra.Numerator, IntegerMath.GenericMul(b, ra.Denominator)));
        }
        if (b is Rational rb2)
            return Math.Sign(IntegerMath.Compare(IntegerMath.GenericMul(a, rb2.Denominator), rb2.Numerator));
        return Math.Sign(IntegerMath.Compare(a, b));
    }
}
