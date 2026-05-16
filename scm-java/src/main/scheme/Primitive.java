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
     * Compare mixed exact/inexact numbers without precision loss.
     * Converts the inexact value to exact (BigInteger) when it's integral,
     * avoiding the double->long cast that loses precision beyond 2^53.
     */
    public static boolean mixedNumericEquals(Object a, Object b) {
        double d; Object exact;
        if (Value.isReal(a) && Value.isInteger(b)) { d = Value.asReal(a); exact = b; }
        else if (Value.isInteger(a) && Value.isReal(b)) { d = Value.asReal(b); exact = a; }
        else { return asDouble(a) == asDouble(b); }

        if (Double.isNaN(d) || Double.isInfinite(d)) return false;
        if (d != Math.floor(d)) return false; // non-integral double != integer
        // Convert double to BigInteger for precise comparison
        return IntegerMath.genericEquals(new java.math.BigDecimal(d).toBigInteger(), exact);
    }

    /**
     * Compare mixed exact/inexact for ordering (< or >).
     * Returns negative if a < b, positive if a > b, 0 if equal.
     */
    public static int mixedNumericCompare(Object a, Object b) {
        double d; Object exact; boolean flipped;
        if (Value.isReal(a) && Value.isInteger(b)) { d = Value.asReal(a); exact = b; flipped = false; }
        else if (Value.isInteger(a) && Value.isReal(b)) { d = Value.asReal(b); exact = a; flipped = true; }
        else { double da = asDouble(a), db = asDouble(b); return da < db ? -1 : da > db ? 1 : 0; }

        if (Double.isNaN(d)) return 0; // NaN comparisons are unordered
        if (d == Double.POSITIVE_INFINITY) return flipped ? -1 : 1;
        if (d == Double.NEGATIVE_INFINITY) return flipped ? 1 : -1;

        // Convert double to BigInteger for precise comparison
        BigInteger bi = new java.math.BigDecimal(d).toBigInteger();
        double trunc = d < 0 ? Math.ceil(d) : Math.floor(d);
        double frac = d - trunc;

        int cmp;
        if (exact instanceof Long) cmp = bi.compareTo(BigInteger.valueOf((long)(Long) exact));
        else cmp = bi.compareTo((BigInteger) exact);

        // If integer parts equal but double has fractional part, the double is larger/smaller
        if (cmp == 0 && frac != 0.0) cmp = frac > 0 ? 1 : -1;

        return flipped ? -cmp : cmp;
    }

    private static double asDouble(Object a) {
        if (a instanceof Double) return (double)(Double) a;
        if (a instanceof Long) return (double)(long)(Long) a;
        if (a instanceof BigInteger) return ((BigInteger) a).doubleValue();
        if (a instanceof Rational) return asDouble(((Rational) a).numerator) / asDouble(((Rational) a).denominator);
        return 0.0;
    }
}
