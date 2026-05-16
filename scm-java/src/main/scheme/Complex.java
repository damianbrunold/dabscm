package scheme;

import java.math.BigInteger;

public final class Complex {
    public final Object real;  // Long, BigInteger, Rational, or Double
    public final Object imag;  // Long, BigInteger, Rational, or Double

    Complex(Object real, Object imag) {
        this.real = real;
        this.imag = imag;
    }

    /**
     * Creates a complex number, collapsing to a real if imaginary part is zero.
     * Normalizes exactness: if either part is inexact, both become inexact.
     */
    public static Object create(Object real, Object imag) {
        // Collapse to real only if imaginary part is EXACT zero.
        // Inexact 0.0 is preserved to maintain complex identity per R7RS.
        if (isExactZero(imag)) {
            return real;
        }

        boolean realExact = isExact(real);
        boolean imagExact = isExact(imag);

        if (realExact != imagExact) {
            if (realExact) real = toInexact(real);
            else imag = toInexact(imag);
        }

        return new Complex(real, imag);
    }

    private static boolean isExactZero(Object v) {
        if (v instanceof Long) return (long)(Long) v == 0;
        if (v instanceof java.math.BigInteger) return ((java.math.BigInteger) v).signum() == 0;
        return false;
    }

    // --- Part type helpers ---

    public static boolean isExact(Object v) {
        return v instanceof Long || v instanceof BigInteger || v instanceof Rational;
    }

    private static boolean isZero(Object v) {
        if (v instanceof Long) return (long)(Long) v == 0;
        if (v instanceof Double) return (double)(Double) v == 0.0;
        if (v instanceof BigInteger) return ((BigInteger) v).signum() == 0;
        return false;
    }

    private static boolean isPartNegative(Object v) {
        if (v instanceof Long) return (long)(Long) v < 0;
        if (v instanceof Double) return (double)(Double) v < 0.0;
        if (v instanceof BigInteger) return ((BigInteger) v).signum() < 0;
        if (v instanceof Rational) return isPartNegative(((Rational) v).numerator);
        return false;
    }

    public static Object toInexact(Object v) {
        if (v instanceof Double) return v;
        if (v instanceof Long) return (double)(long)(Long) v;
        if (v instanceof BigInteger) return ((BigInteger) v).doubleValue();
        if (v instanceof Rational) return ((Rational) v).toDouble();
        return 0.0;
    }

    public static Object toExact(Object v) {
        if (v instanceof Long || v instanceof BigInteger || v instanceof Rational) return v;
        if (v instanceof Double) {
            double d = (double)(Double) v;
            if (Double.isNaN(d) || Double.isInfinite(d))
                throw new SchemeError("exact: no exact equivalent for ~s", d);
            if (d == Math.floor(d)) {
                long l = (long) d;
                if ((double) l == d) return l;
                return IntegerMath.normalize(new java.math.BigDecimal(d).toBigInteger());
            }
            return doubleToExact(d);
        }
        return v;
    }

    private static Object doubleToExact(double d) {
        if (d == 0.0) return 0L;
        boolean neg = d < 0;
        if (neg) d = -d;
        long bits = Double.doubleToLongBits(d);
        int exp = (int)((bits >> 52) & 0x7FFL) - 1023 - 52;
        long mantissa = (bits & 0xFFFFFFFFFFFFFL) | (1L << 52);
        BigInteger num = BigInteger.valueOf(mantissa);
        BigInteger den = BigInteger.ONE;
        if (exp >= 0) { num = num.shiftLeft(exp); }
        else { den = den.shiftLeft(-exp); }
        BigInteger g = num.gcd(den);
        num = num.divide(g);
        den = den.divide(g);
        if (neg) num = num.negate();
        if (den.equals(BigInteger.ONE))
            return IntegerMath.normalize(num);
        return Rational.create(IntegerMath.normalize(num), IntegerMath.normalize(den));
    }

    // --- Part arithmetic ---

    static Object partAdd(Object a, Object b) {
        if (a instanceof Long && b instanceof Long) {
            try { return Math.addExact((long)(Long) a, (long)(Long) b); }
            catch (ArithmeticException e) {
                return IntegerMath.normalize(
                    BigInteger.valueOf((long)(Long) a).add(BigInteger.valueOf((long)(Long) b)));
            }
        }
        if (Value.isInteger(a) && Value.isInteger(b)) return IntegerMath.genericAdd(a, b);
        if (a instanceof Double || b instanceof Double) return partToDouble(a) + partToDouble(b);
        return Rational.add(a, b);
    }

    static Object partSub(Object a, Object b) {
        if (a instanceof Long && b instanceof Long) {
            try { return Math.subtractExact((long)(Long) a, (long)(Long) b); }
            catch (ArithmeticException e) {
                return IntegerMath.normalize(
                    BigInteger.valueOf((long)(Long) a).subtract(BigInteger.valueOf((long)(Long) b)));
            }
        }
        if (Value.isInteger(a) && Value.isInteger(b)) return IntegerMath.genericSub(a, b);
        if (a instanceof Double || b instanceof Double) return partToDouble(a) - partToDouble(b);
        return Rational.sub(a, b);
    }

    static Object partMul(Object a, Object b) {
        if (a instanceof Long && b instanceof Long) {
            try { return Math.multiplyExact((long)(Long) a, (long)(Long) b); }
            catch (ArithmeticException e) {
                return IntegerMath.normalize(
                    BigInteger.valueOf((long)(Long) a).multiply(BigInteger.valueOf((long)(Long) b)));
            }
        }
        if (Value.isInteger(a) && Value.isInteger(b)) return IntegerMath.genericMul(a, b);
        if (a instanceof Double || b instanceof Double) return partToDouble(a) * partToDouble(b);
        return Rational.mul(a, b);
    }

    static Object partDiv(Object a, Object b) {
        if (a instanceof Double || b instanceof Double) return partToDouble(a) / partToDouble(b);
        return Rational.div(a, b);
    }

    static Object partNegate(Object a) {
        if (a instanceof Long) return IntegerMath.negate((long)(Long) a);
        if (a instanceof BigInteger) return IntegerMath.genericNegate(a);
        if (a instanceof Double) return -(double)(Double) a;
        return Rational.sub(0L, a);
    }

    public static double partToDouble(Object v) {
        if (v instanceof Double) return (double)(Double) v;
        if (v instanceof Long) return (double)(long)(Long) v;
        if (Value.isBigInteger(v)) return IntegerMath.toDouble(v);
        if (v instanceof Rational) return ((Rational) v).toDouble();
        return 0.0;
    }

    // --- Complex arithmetic ---

    private static Object[] extractParts(Object v) {
        if (v instanceof Complex) {
            Complex c = (Complex) v;
            return new Object[] { c.real, c.imag };
        }
        return new Object[] { v, isExact(v) ? (Object) 0L : 0.0 };
    }

    public static Object add(Object a, Object b) {
        Object[] ap = extractParts(a), bp = extractParts(b);
        return create(partAdd(ap[0], bp[0]), partAdd(ap[1], bp[1]));
    }

    public static Object sub(Object a, Object b) {
        Object[] ap = extractParts(a), bp = extractParts(b);
        return create(partSub(ap[0], bp[0]), partSub(ap[1], bp[1]));
    }

    public static Object negate(Object a) {
        if (a instanceof Complex) {
            Complex c = (Complex) a;
            return create(partNegate(c.real), partNegate(c.imag));
        }
        return partNegate(a);
    }

    public static Object mul(Object a, Object b) {
        Object[] ap = extractParts(a), bp = extractParts(b);
        Object ar = ap[0], ai = ap[1], br = bp[0], bi = bp[1];
        // (ar + ai*i)(br + bi*i) = (ar*br - ai*bi) + (ar*bi + ai*br)*i
        Object realPart = partSub(partMul(ar, br), partMul(ai, bi));
        Object imagPart = partAdd(partMul(ar, bi), partMul(ai, br));
        return create(realPart, imagPart);
    }

    public static Object div(Object a, Object b) {
        Object[] ap = extractParts(a), bp = extractParts(b);
        Object ar = ap[0], ai = ap[1], br = bp[0], bi = bp[1];
        // (ar + ai*i) / (br + bi*i)
        Object denom = partAdd(partMul(br, br), partMul(bi, bi));
        if (isZero(denom)) throw new SchemeError("/: Division by zero");
        Object realPart = partDiv(partAdd(partMul(ar, br), partMul(ai, bi)), denom);
        Object imagPart = partDiv(partSub(partMul(ai, br), partMul(ar, bi)), denom);
        return create(realPart, imagPart);
    }

    // --- Magnitude and angle ---

    public static double magnitude(Complex c) {
        double r = partToDouble(c.real);
        double i = partToDouble(c.imag);
        return Math.sqrt(r * r + i * i);
    }

    public static double angle(Complex c) {
        double r = partToDouble(c.real);
        double i = partToDouble(c.imag);
        return Math.atan2(i, r);
    }

    // --- Equality ---

    @Override
    public boolean equals(Object obj) {
        if (!(obj instanceof Complex)) return false;
        Complex other = (Complex) obj;
        return partEquals(real, other.real) && partEquals(imag, other.imag);
    }

    @Override
    public int hashCode() {
        return real.hashCode() * 31 + imag.hashCode();
    }

    /**
     * Strict equality: same type and value (for eqv?).
     */
    private static boolean partEquals(Object a, Object b) {
        if (a instanceof Long && b instanceof Long) return a.equals(b);
        if (Value.isInteger(a) && Value.isInteger(b)) return IntegerMath.genericEquals(a, b);
        if (a instanceof Double && b instanceof Double) return a.equals(b);
        if (a instanceof Rational && b instanceof Rational) return a.equals(b);
        return false;
    }

    /**
     * Numeric equality across exactness (for =).
     */
    public static boolean numericEquals(Object a, Object b) {
        Object[] ap = extractParts(a), bp = extractParts(b);
        return numericPartEquals(ap[0], bp[0]) && numericPartEquals(ap[1], bp[1]);
    }

    private static boolean numericPartEquals(Object a, Object b) {
        if (a instanceof Long && b instanceof Long) return a.equals(b);
        if (Value.isInteger(a) && Value.isInteger(b)) return IntegerMath.genericEquals(a, b);
        if (a instanceof Double && b instanceof Double) return a.equals(b);
        if (a instanceof Rational && b instanceof Rational) return a.equals(b);
        return Primitive.mixedNumericEquals(a, b);
    }

    // --- String representation ---

    @Override
    public String toString() {
        StringBuilder sb = new StringBuilder();
        appendPart(sb, real);

        boolean negImag = isPartNegative(imag);
        sb.append(negImag ? '-' : '+');
        appendAbsImag(sb, imag);
        sb.append('i');

        return sb.toString();
    }

    private static void appendPart(StringBuilder sb, Object v) {
        if (v instanceof Double) sb.append(Value.formatDouble((double)(Double) v));
        else if (v instanceof Rational) sb.append(v.toString());
        else sb.append(v);
    }

    private static void appendAbsImag(StringBuilder sb, Object v) {
        if (v instanceof Double) {
            double d = (double)(Double) v;
            if (Double.isNaN(d)) sb.append("nan.0");
            else if (Double.isInfinite(d)) sb.append("inf.0");
            else sb.append(Value.formatDouble(Math.abs(d)));
        } else {
            Object abs = partAbs(v);
            if (abs instanceof Rational) sb.append(abs.toString());
            else sb.append(abs);
        }
    }

    private static Object partAbs(Object v) {
        if (v instanceof Long) {
            long l = (long)(Long) v;
            return l >= 0 ? (Object) l : IntegerMath.negate(l);
        }
        if (v instanceof BigInteger) return IntegerMath.genericAbs(v);
        if (v instanceof Rational) {
            Rational r = (Rational) v;
            if (IntegerMath.isNegative(r.numerator))
                return Rational.create(IntegerMath.genericNegate(r.numerator), r.denominator);
            return r;
        }
        return v;
    }
}
