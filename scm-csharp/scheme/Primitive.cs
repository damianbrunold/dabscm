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
    /// Compare mixed exact/inexact numbers without precision loss.
    /// Converts the inexact value to exact (BigInteger) when it's integral,
    /// avoiding the double→long cast that loses precision beyond 2^53.
    /// </summary>
    public static bool MixedNumericEquals(object a, object b)
    {
        double d; object exact;
        if (Value.IsReal(a) && Value.IsInteger(b)) { d = Value.AsReal(a); exact = b; }
        else if (Value.IsInteger(a) && Value.IsReal(b)) { d = Value.AsReal(b); exact = a; }
        else { return AsDouble(a) == AsDouble(b); }

        if (double.IsNaN(d) || double.IsInfinity(d)) return false;
        if (d != Math.Floor(d)) return false; // non-integral double ≠ integer
        // Convert double to BigInteger for precise comparison
        return IntegerMath.GenericEquals(new System.Numerics.BigInteger(d), exact);
    }

    /// <summary>
    /// Compare mixed exact/inexact for ordering (< or >).
    /// Returns negative if a < b, positive if a > b, 0 if equal.
    /// </summary>
    public static int MixedNumericCompare(object a, object b)
    {
        double d; object exact; bool flipped;
        if (Value.IsReal(a) && Value.IsInteger(b)) { d = Value.AsReal(a); exact = b; flipped = false; }
        else if (Value.IsInteger(a) && Value.IsReal(b)) { d = Value.AsReal(b); exact = a; flipped = true; }
        else { double da = AsDouble(a), db = AsDouble(b); return da < db ? -1 : da > db ? 1 : 0; }

        if (double.IsNaN(d)) return 0; // NaN comparisons are unordered
        if (double.IsPositiveInfinity(d)) return flipped ? -1 : 1;
        if (double.IsNegativeInfinity(d)) return flipped ? 1 : -1;

        // Convert double to BigInteger for precise comparison
        var bi = new System.Numerics.BigInteger(d);
        double frac = d - Math.Truncate(d);

        int cmp;
        if (exact is long el) cmp = bi.CompareTo(new System.Numerics.BigInteger(el));
        else cmp = bi.CompareTo((System.Numerics.BigInteger)exact);

        // If integer parts equal but double has fractional part, the double is larger/smaller
        if (cmp == 0 && frac != 0.0) cmp = frac > 0 ? 1 : -1;

        return flipped ? -cmp : cmp;
    }

    private static double AsDouble(object a)
    {
        if (a is double d) return d;
        if (a is long l) return (double)l;
        if (a is System.Numerics.BigInteger bi) return (double)bi;
        if (a is Rational r) return AsDouble(r.Numerator) / AsDouble(r.Denominator);
        return 0.0;
    }
}
