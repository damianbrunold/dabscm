using System.Numerics;

namespace scheme;

public static class IntegerMath
{
    // --- Overflow-checked long+long arithmetic ---

    public static object Add(long a, long b)
    {
        try { checked { return a + b; } }
        catch (OverflowException) { return (BigInteger)a + b; }
    }

    public static object Sub(long a, long b)
    {
        try { checked { return a - b; } }
        catch (OverflowException) { return (BigInteger)a - b; }
    }

    public static object Mul(long a, long b)
    {
        try { checked { return a * b; } }
        catch (OverflowException) { return (BigInteger)a * b; }
    }

    public static object Negate(long a)
    {
        if (a == long.MinValue) return -(BigInteger)a;
        return -a;
    }

    // --- Normalize: demote BigInteger to long when possible ---

    public static object Normalize(BigInteger value)
    {
        if (value >= long.MinValue && value <= long.MaxValue)
            return (long)value;
        return value;
    }

    // --- Lift to BigInteger ---

    public static BigInteger ToBigInteger(object value)
    {
        if (value is long l) return l;
        return (BigInteger)value;
    }

    // --- Generic dispatch (handles long/BigInteger combinations) ---

    public static object GenericAdd(object a, object b)
    {
        if (a is long la && b is long lb) return Add(la, lb);
        return Normalize(ToBigInteger(a) + ToBigInteger(b));
    }

    public static object GenericSub(object a, object b)
    {
        if (a is long la && b is long lb) return Sub(la, lb);
        return Normalize(ToBigInteger(a) - ToBigInteger(b));
    }

    public static object GenericMul(object a, object b)
    {
        if (a is long la && b is long lb) return Mul(la, lb);
        return Normalize(ToBigInteger(a) * ToBigInteger(b));
    }

    public static object GenericNegate(object a)
    {
        if (a is long la) return Negate(la);
        return Normalize(-ToBigInteger(a));
    }

    public static object GenericQuotient(object a, object b)
    {
        if (a is long la && b is long lb)
        {
            if (la == long.MinValue && lb == -1) return -(BigInteger)long.MinValue;
            return la / lb;
        }
        BigInteger ba = ToBigInteger(a), bb = ToBigInteger(b);
        BigInteger result = BigInteger.Divide(ba, bb);
        // Truncate toward zero (BigInteger.Divide already does this)
        return Normalize(result);
    }

    public static object GenericRemainder(object a, object b)
    {
        if (a is long la && b is long lb)
        {
            if (la == long.MinValue && lb == -1) return 0L;
            return la % lb;
        }
        return Normalize(BigInteger.Remainder(ToBigInteger(a), ToBigInteger(b)));
    }

    public static object GenericModulo(object a, object b)
    {
        if (a is long la && b is long lb)
        {
            if (la == long.MinValue && lb == -1) return 0L;
            long r = la % lb;
            if ((r >= 0) != (lb >= 0)) return r + lb;
            return r;
        }
        BigInteger ba = ToBigInteger(a), bb = ToBigInteger(b);
        BigInteger r2 = BigInteger.Remainder(ba, bb);
        if ((r2.Sign >= 0) != (bb.Sign >= 0)) r2 += bb;
        return Normalize(r2);
    }

    public static object GenericAbs(object a)
    {
        if (a is long la) return la >= 0 ? la : Negate(la);
        return Normalize(BigInteger.Abs(ToBigInteger(a)));
    }

    // --- Exponentiation ---

    public static object Expt(object baseVal, long exponent)
    {
        if (exponent == 0) return 1L;
        if (exponent < 0)
            throw new SchemeError("expt: negative exponent with integer base requires rational result");
        if (exponent > int.MaxValue)
            throw new SchemeError("expt: exponent too large");
        BigInteger b = ToBigInteger(baseVal);
        return Normalize(BigInteger.Pow(b, (int)exponent));
    }

    // --- Comparison ---

    public static int Compare(object a, object b)
    {
        if (a is long la && b is long lb) return la.CompareTo(lb);
        return ToBigInteger(a).CompareTo(ToBigInteger(b));
    }

    public static bool GenericEquals(object a, object b)
    {
        if (a is long la && b is long lb) return la == lb;
        return ToBigInteger(a).Equals(ToBigInteger(b));
    }

    // --- Conversion to int (for array indices etc.) ---

    public static int ToInt(object value)
    {
        if (value is long l)
        {
            if (l < int.MinValue || l > int.MaxValue)
                throw new SchemeError("value out of range: ~s", l);
            return (int)l;
        }
        throw new SchemeError("value out of range: ~s", value);
    }

    public static long ToLong(object value)
    {
        if (value is long l) return l;
        BigInteger bi = (BigInteger)value;
        if (bi >= long.MinValue && bi <= long.MaxValue) return (long)bi;
        throw new SchemeError("value out of range: ~s", value);
    }

    // --- Conversion to double ---

    public static double ToDouble(object value)
    {
        if (value is long l) return (double)l;
        return (double)(BigInteger)value;
    }

    // --- Bitwise operations ---

    public static object BitwiseAnd(object a, object b)
    {
        if (a is long la && b is long lb) return la & lb;
        return Normalize(ToBigInteger(a) & ToBigInteger(b));
    }

    public static object BitwiseIor(object a, object b)
    {
        if (a is long la && b is long lb) return la | lb;
        return Normalize(ToBigInteger(a) | ToBigInteger(b));
    }

    public static object BitwiseXor(object a, object b)
    {
        if (a is long la && b is long lb) return la ^ lb;
        return Normalize(ToBigInteger(a) ^ ToBigInteger(b));
    }

    public static object BitwiseNot(object a)
    {
        if (a is long la) return ~la;
        return Normalize(~ToBigInteger(a));
    }

    public static object ArithmeticShift(object value, long count)
    {
        if (count == 0) return value;
        if (count > 0)
        {
            // Left shift
            if (count > int.MaxValue)
                throw new SchemeError("arithmetic-shift: shift count too large");
            BigInteger bv = ToBigInteger(value);
            return Normalize(bv << (int)count);
        }
        else
        {
            // Right shift
            long rcount = -count;
            if (value is long lv)
            {
                if (rcount >= 63) return lv >= 0 ? 0L : -1L;
                return lv >> (int)rcount;
            }
            if (rcount > int.MaxValue)
                throw new SchemeError("arithmetic-shift: shift count too large");
            return Normalize(ToBigInteger(value) >> (int)rcount);
        }
    }

    public static long BitCount(object value)
    {
        if (value is long lv)
        {
            if (lv < 0) lv = ~lv;
            return (long)System.Numerics.BitOperations.PopCount((ulong)lv);
        }
        BigInteger bv = ToBigInteger(value);
        if (bv < 0) bv = ~bv;
        long count = 0;
        while (bv > 0) { count += (long)System.Numerics.BitOperations.PopCount((ulong)(bv & ulong.MaxValue)); bv >>= 64; }
        return count;
    }

    public static long IntegerLength(object value)
    {
        if (value is long lv)
        {
            if (lv < 0) lv = ~lv;
            return 64 - (long)System.Numerics.BitOperations.LeadingZeroCount((ulong)lv);
        }
        BigInteger bv = ToBigInteger(value);
        if (bv < 0) bv = ~bv;
        return (long)bv.GetBitLength();
    }

    // --- GCD (used by Rational) ---

    public static object Gcd(object a, object b)
    {
        if (a is long la && b is long lb)
        {
            la = Math.Abs(la);
            lb = Math.Abs(lb);
            while (lb != 0) { long t = lb; lb = la % lb; la = t; }
            return la == 0 ? 1L : la;
        }
        BigInteger ba = BigInteger.Abs(ToBigInteger(a));
        BigInteger bb = BigInteger.Abs(ToBigInteger(b));
        BigInteger result = BigInteger.GreatestCommonDivisor(ba, bb);
        return result.IsZero ? (object)1L : Normalize(result);
    }

    // --- Sign helpers ---

    public static int Sign(object a)
    {
        if (a is long la) return la < 0 ? -1 : (la > 0 ? 1 : 0);
        return ToBigInteger(a).Sign;
    }

    public static bool IsZero(object a)
    {
        if (a is long la) return la == 0;
        return ToBigInteger(a).IsZero;
    }

    public static bool IsNegative(object a)
    {
        if (a is long la) return la < 0;
        return ToBigInteger(a).Sign < 0;
    }
}
