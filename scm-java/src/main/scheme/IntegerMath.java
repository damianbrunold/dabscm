package scheme;

import java.math.BigInteger;

public final class IntegerMath {

    private IntegerMath() {}

    // --- Overflow-checked long+long arithmetic ---

    public static Object add(long a, long b) {
        try { return Math.addExact(a, b); }
        catch (ArithmeticException e) {
            return normalize(BigInteger.valueOf(a).add(BigInteger.valueOf(b)));
        }
    }

    public static Object sub(long a, long b) {
        try { return Math.subtractExact(a, b); }
        catch (ArithmeticException e) {
            return normalize(BigInteger.valueOf(a).subtract(BigInteger.valueOf(b)));
        }
    }

    public static Object mul(long a, long b) {
        try { return Math.multiplyExact(a, b); }
        catch (ArithmeticException e) {
            return normalize(BigInteger.valueOf(a).multiply(BigInteger.valueOf(b)));
        }
    }

    public static Object negate(long a) {
        if (a == Long.MIN_VALUE) return BigInteger.valueOf(a).negate();
        return -a;
    }

    // --- Normalize: demote BigInteger to long when possible ---

    public static Object normalize(BigInteger value) {
        if (value.bitLength() < 64) return value.longValueExact();
        // bitLength() == 63 means it fits in long (positive), but Long.MIN_VALUE
        // has bitLength() == 63 too. longValueExact handles all correctly.
        try { return value.longValueExact(); }
        catch (ArithmeticException e) { return value; }
    }

    // --- Lift to BigInteger ---

    public static BigInteger toBigInteger(Object value) {
        if (value instanceof Long) return BigInteger.valueOf((long)(Long) value);
        return (BigInteger) value;
    }

    // --- Generic dispatch (handles long/BigInteger combinations) ---

    public static Object genericAdd(Object a, Object b) {
        if (a instanceof Long && b instanceof Long) return add((long)(Long) a, (long)(Long) b);
        return normalize(toBigInteger(a).add(toBigInteger(b)));
    }

    public static Object genericSub(Object a, Object b) {
        if (a instanceof Long && b instanceof Long) return sub((long)(Long) a, (long)(Long) b);
        return normalize(toBigInteger(a).subtract(toBigInteger(b)));
    }

    public static Object genericMul(Object a, Object b) {
        if (a instanceof Long && b instanceof Long) return mul((long)(Long) a, (long)(Long) b);
        return normalize(toBigInteger(a).multiply(toBigInteger(b)));
    }

    public static Object genericNegate(Object a) {
        if (a instanceof Long) return negate((long)(Long) a);
        return normalize(toBigInteger(a).negate());
    }

    public static Object genericQuotient(Object a, Object b) {
        if (a instanceof Long && b instanceof Long) {
            long la = (long)(Long) a, lb = (long)(Long) b;
            if (la == Long.MIN_VALUE && lb == -1)
                return BigInteger.valueOf(la).negate();
            return la / lb;
        }
        BigInteger ba = toBigInteger(a), bb = toBigInteger(b);
        // BigInteger division truncates toward zero
        BigInteger[] qr = ba.divideAndRemainder(bb);
        return normalize(qr[0]);
    }

    public static Object genericRemainder(Object a, Object b) {
        if (a instanceof Long && b instanceof Long) {
            long la = (long)(Long) a, lb = (long)(Long) b;
            if (la == Long.MIN_VALUE && lb == -1) return 0L;
            return la % lb;
        }
        return normalize(toBigInteger(a).remainder(toBigInteger(b)));
    }

    public static Object genericModulo(Object a, Object b) {
        if (a instanceof Long && b instanceof Long) {
            long la = (long)(Long) a, lb = (long)(Long) b;
            if (la == Long.MIN_VALUE && lb == -1) return 0L;
            long r = la % lb;
            if ((r >= 0) != (lb >= 0)) return r + lb;
            return r;
        }
        BigInteger ba = toBigInteger(a), bb = toBigInteger(b);
        BigInteger r = ba.remainder(bb);
        if ((r.signum() >= 0) != (bb.signum() >= 0)) r = r.add(bb);
        return normalize(r);
    }

    public static Object genericAbs(Object a) {
        if (a instanceof Long) {
            long la = (long)(Long) a;
            return la >= 0 ? la : negate(la);
        }
        return normalize(toBigInteger(a).abs());
    }

    // --- Exponentiation ---

    public static Object expt(Object baseVal, long exponent) {
        if (exponent == 0) return 1L;
        if (exponent < 0)
            throw new SchemeError("expt: negative exponent with integer base requires rational result");
        if (exponent > Integer.MAX_VALUE)
            throw new SchemeError("expt: exponent too large");
        BigInteger b = toBigInteger(baseVal);
        return normalize(b.pow((int) exponent));
    }

    // --- Comparison ---

    public static int compare(Object a, Object b) {
        if (a instanceof Long && b instanceof Long)
            return Long.compare((long)(Long) a, (long)(Long) b);
        return toBigInteger(a).compareTo(toBigInteger(b));
    }

    public static boolean genericEquals(Object a, Object b) {
        if (a instanceof Long && b instanceof Long)
            return ((long)(Long) a) == ((long)(Long) b);
        return toBigInteger(a).equals(toBigInteger(b));
    }

    // --- Conversion to int (for array indices etc.) ---

    public static int toInt(Object value) {
        if (value instanceof Long) {
            long l = (long)(Long) value;
            if (l < Integer.MIN_VALUE || l > Integer.MAX_VALUE)
                throw new SchemeError("value out of range: ~s", l);
            return (int) l;
        }
        throw new SchemeError("value out of range: ~s", value);
    }

    public static long toLong(Object value) {
        if (value instanceof Long) return (long)(Long) value;
        BigInteger bi = (BigInteger) value;
        try { return bi.longValueExact(); }
        catch (ArithmeticException e) {
            throw new SchemeError("value out of range: ~s", value);
        }
    }

    // --- Conversion to double ---

    public static double toDouble(Object value) {
        if (value instanceof Long) return (double)(long)(Long) value;
        return toBigInteger(value).doubleValue();
    }

    // --- Bitwise operations ---

    public static Object bitwiseAnd(Object a, Object b) {
        if (a instanceof Long && b instanceof Long) return (long)(Long) a & (long)(Long) b;
        return normalize(toBigInteger(a).and(toBigInteger(b)));
    }

    public static Object bitwiseIor(Object a, Object b) {
        if (a instanceof Long && b instanceof Long) return (long)(Long) a | (long)(Long) b;
        return normalize(toBigInteger(a).or(toBigInteger(b)));
    }

    public static Object bitwiseXor(Object a, Object b) {
        if (a instanceof Long && b instanceof Long) return (long)(Long) a ^ (long)(Long) b;
        return normalize(toBigInteger(a).xor(toBigInteger(b)));
    }

    public static Object bitwiseNot(Object a) {
        if (a instanceof Long) return ~(long)(Long) a;
        return normalize(toBigInteger(a).not());
    }

    public static Object arithmeticShift(Object value, long count) {
        if (count == 0) return value;
        if (count > 0) {
            // Left shift
            if (count > Integer.MAX_VALUE)
                throw new SchemeError("arithmetic-shift: shift count too large");
            BigInteger bv = toBigInteger(value);
            return normalize(bv.shiftLeft((int) count));
        } else {
            // Right shift
            long rcount = -count;
            if (value instanceof Long) {
                long lv = (long)(Long) value;
                if (rcount >= 63) return lv >= 0 ? 0L : -1L;
                return lv >> (int) rcount;
            }
            if (rcount > Integer.MAX_VALUE)
                throw new SchemeError("arithmetic-shift: shift count too large");
            return normalize(toBigInteger(value).shiftRight((int) rcount));
        }
    }

    public static long bitCount(Object value) {
        if (value instanceof Long) {
            long lv = (long)(Long) value;
            if (lv < 0) lv = ~lv;
            return Long.bitCount(lv);
        }
        BigInteger bv = toBigInteger(value);
        // BigInteger.bitCount() already returns bits differing from sign bit,
        // which is the SRFI 151 semantics for both positive and negative.
        return bv.bitCount();
    }

    public static long integerLength(Object value) {
        if (value instanceof Long) {
            long lv = (long)(Long) value;
            if (lv < 0) lv = ~lv;
            return 64 - Long.numberOfLeadingZeros(lv);
        }
        BigInteger bv = toBigInteger(value);
        if (bv.signum() < 0) bv = bv.not();
        return bv.bitLength();
    }

    // --- GCD (used by Rational) ---

    public static Object gcd(Object a, Object b) {
        if (a instanceof Long && b instanceof Long) {
            long la = Math.abs((long)(Long) a);
            long lb = Math.abs((long)(Long) b);
            while (lb != 0) { long t = lb; lb = la % lb; la = t; }
            return la == 0 ? 1L : la;
        }
        BigInteger ba = toBigInteger(a).abs();
        BigInteger bb = toBigInteger(b).abs();
        BigInteger result = ba.gcd(bb);
        return result.equals(BigInteger.ZERO) ? (Object) 1L : normalize(result);
    }

    // --- Sign helpers ---

    public static int sign(Object a) {
        if (a instanceof Long) {
            long la = (long)(Long) a;
            return la < 0 ? -1 : (la > 0 ? 1 : 0);
        }
        return toBigInteger(a).signum();
    }

    public static boolean isZero(Object a) {
        if (a instanceof Long) return (long)(Long) a == 0;
        return toBigInteger(a).equals(BigInteger.ZERO);
    }

    public static boolean isNegative(Object a) {
        if (a instanceof Long) return (long)(Long) a < 0;
        return toBigInteger(a).signum() < 0;
    }
}
