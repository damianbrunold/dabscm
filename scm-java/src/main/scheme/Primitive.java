package scheme;

import java.math.BigInteger;

public abstract class Primitive {
    public abstract String name();
    public abstract String info();
    public abstract Object apply(SourcePos pos, Object[] arguments);

    protected void checkArgs(SourcePos pos, Object[] arguments, int minArgs, int maxArgs) {
        if (minArgs == maxArgs && arguments.length != minArgs) {
            throw new SchemeError(
                pos,
                "~s needs ~s arguments, but got ~s",
                name(), minArgs, arguments.length
            );
        }
        if (maxArgs == -1 && arguments.length < minArgs) {
            throw new SchemeError(
                pos,
                "~s needs at least ~s arguments, but got ~s",
                name(), minArgs, arguments.length
            );
        }
        if (maxArgs != -1 && (arguments.length < minArgs || arguments.length > maxArgs)) {
            throw new SchemeError(
                pos,
                "~s needs between ~s and ~s arguments, but got ~s",
                name(), minArgs, maxArgs, arguments.length
            );
        }
    }

    @Override
    public String toString()
    {
        return "#<p:" + name() + ">";
    }

    protected double toReal(Object value) {
        if (value instanceof Long) return (double) (long) (Long) value;
        if (Value.isBigInteger(value)) return IntegerMath.toDouble(value);
        if (value instanceof Rational) return ((Rational) value).toDouble();
        return (double) (Double) value;
    }

    protected boolean allIntegers(Object[] args) {
        for (Object arg : args) {
            if (!Value.isInteger(arg)) {
                return false;
            }
        }
        return true;
    }

    protected boolean allExactNums(Object[] args) {
        for (Object arg : args) {
            if (!Value.isInteger(arg) && !Value.isRational(arg))
                return false;
        }
        return true;
    }

    protected boolean hasComplex(Object[] args) {
        for (Object arg : args) {
            if (arg instanceof Complex) return true;
        }
        return false;
    }

    protected Object toIntegerIfPossible(Object value) {
        if (Value.isInteger(value)) return value;
        double val = toReal(value);
        if (val == Math.floor(val)) return (long) val;
        return value;
    }

    /**
     * = for real numbers that are not both integers or both doubles.
     * Exact numbers (integers, rationals) are compared exactly, a finite
     * double against an exact number via its exact value. A non-number
     * throws WrongTypeException ("wrong argument type" with the value).
     */
    public static boolean mixedNumericEquals(Object a, Object b) {
        if (a instanceof Double) {
            double da = (Double) a;
            return b instanceof Double ? da == (Double) b : doubleExactCompare(da, b, true) == 0;
        }
        if (b instanceof Double) return doubleExactCompare((Double) b, a, true) == 0;
        checkExact(a); checkExact(b);
        return exactCompare(a, b) == 0;
    }

    /**
     * Ordering for real numbers that are not both integers or both doubles,
     * exact like mixedNumericEquals. Returns -1 if a < b, 1 if a > b, 0 if
     * equal and UNORDERED if one is NaN (then every comparison is false).
     */
    public static int mixedNumericCompare(Object a, Object b) {
        if (a instanceof Double) {
            double da = (Double) a;
            return b instanceof Double ? doubleCompare(da, (Double) b) : doubleExactCompare(da, b, false);
        }
        if (b instanceof Double) {
            int c = doubleExactCompare((Double) b, a, false);
            return c == UNORDERED ? c : -c;
        }
        checkExact(a); checkExact(b);
        return exactCompare(a, b);
    }

    public static final int UNORDERED = 2;

    // <, >, <= and >= for operands mixedNumericCompare accepts.
    public static boolean numLess(Object a, Object b) { return mixedNumericCompare(a, b) == -1; }
    public static boolean numGreater(Object a, Object b) { return mixedNumericCompare(a, b) == 1; }
    public static boolean numLessEq(Object a, Object b) { int c = mixedNumericCompare(a, b); return c == -1 || c == 0; }
    public static boolean numGreaterEq(Object a, Object b) { int c = mixedNumericCompare(a, b); return c == 0 || c == 1; }

    private static final long MAX_EXACT_DOUBLE = 1L << 53;

    private static int doubleCompare(double a, double b) {
        return a < b ? -1 : a > b ? 1 : a == b ? 0 : UNORDERED;
    }

    // Compares double d with exact x; for equality (forEquals), NaN and
    // infinities are unequal to everything (1), for ordering NaN is UNORDERED.
    private static int doubleExactCompare(double d, Object x, boolean forEquals) {
        checkExact(x);
        // Fast paths without allocation. A long within 2^53 is exact as a
        // double. n/d of longs within 2^53 is correctly rounded, and rounding
        // keeps the order, so a rounded value other than d orders like x.
        if (x instanceof Long) {
            long l = (Long) x;
            if (l >= -MAX_EXACT_DOUBLE && l <= MAX_EXACT_DOUBLE)
                return forEquals ? (d == (double) l ? 0 : 1) : doubleCompare(d, (double) l);
        }
        if (x instanceof Rational) {
            Rational r = (Rational) x;
            if (r.numerator instanceof Long && r.denominator instanceof Long) {
                long n = (Long) r.numerator, den = (Long) r.denominator;
                if (n >= -MAX_EXACT_DOUBLE && n <= MAX_EXACT_DOUBLE && den <= MAX_EXACT_DOUBLE) {
                    double xd = (double) n / (double) den;
                    if (xd != d) return forEquals ? 1 : doubleCompare(d, xd);
                }
            }
        }
        if (Double.isNaN(d)) return forEquals ? 1 : UNORDERED;
        if (Double.isInfinite(d)) return d > 0 ? 1 : -1;
        return exactCompare(Complex.toExact(d), x);
    }

    /**
     * quotient, remainder and modulo with an inexact argument: computed
     * exactly on the integer values, the result as a (correctly rounded)
     * double. A non-integral argument is a wrong argument type.
     */
    protected static double inexactIntegerOp(Object a, Object b, java.util.function.BinaryOperator<Object> op) {
        return IntegerMath.toDouble(op.apply(exactIntegerOf(a), exactIntegerOf(b)));
    }

    private static Object exactIntegerOf(Object v) {
        if (Value.isInteger(v)) return v;
        if (v instanceof Double) {
            double d = (Double) v;
            if (Double.isFinite(d) && d == Math.rint(d)) return Complex.toExact(v);
        }
        throw new WrongTypeException(v, "integer");
    }

    private static void checkExact(Object v) {
        if (!(v instanceof Long || v instanceof BigInteger || v instanceof Rational))
            throw new WrongTypeException(v, "number");
    }

    // Both exact; rational denominators are positive.
    private static int exactCompare(Object a, Object b) {
        if (a instanceof Rational) {
            Rational ra = (Rational) a;
            if (b instanceof Rational) return Integer.signum(ra.compareTo((Rational) b));
            return Integer.signum(IntegerMath.compare(ra.numerator, IntegerMath.genericMul(b, ra.denominator)));
        }
        if (b instanceof Rational) {
            Rational rb = (Rational) b;
            return Integer.signum(IntegerMath.compare(IntegerMath.genericMul(a, rb.denominator), rb.numerator));
        }
        return Integer.signum(IntegerMath.compare(a, b));
    }
}
