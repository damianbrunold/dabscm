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
        // -0.0 too (its sign is printed: -1.0-0.0i); NaN prints as +nan.0
        if (v instanceof Double) { double d = (Double) v; return !Double.isNaN(d) && (d < 0.0 || 1.0 / d < 0); }
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
        int biased = (int)((bits >> 52) & 0x7FFL);
        long mantissa = bits & 0xFFFFFFFFFFFFFL;
        // subnormals have no implicit leading 1 and the exponent of biased 1
        if (biased != 0) mantissa |= 1L << 52; else biased = 1;
        int exp = biased - 1023 - 52;
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

    public static Object partNegate(Object a) {
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
        // an exact zero divisor is an error, an inexact one follows IEEE
        if (isExactZero(denom)) throw new SchemeError("/: Division by zero");
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
        // == ignores the sign of zero (and NaN is unequal to itself)
        if (a instanceof Double && b instanceof Double) return (double)(Double) a == (double)(Double) b;
        if (a instanceof Rational && b instanceof Rational) return a.equals(b);
        return Primitive.mixedNumericEquals(a, b);
    }

    // --- String representation ---

    @Override
    public String toString() {
        return toString(10);
    }

    // The written form with exact parts in radix (inexact parts in decimal)
    public String toString(int radix) {
        StringBuilder sb = new StringBuilder();
        appendPart(sb, real, radix);

        boolean negImag = isPartNegative(imag);
        sb.append(negImag ? '-' : '+');
        appendAbsImag(sb, imag, radix);
        sb.append('i');

        return sb.toString();
    }

    private static String exactString(Object v, int radix) {
        if (radix == 10) return v.toString();
        if (v instanceof Rational) {
            Rational q = (Rational) v;
            return IntegerMath.toBigInteger(q.numerator).toString(radix) + "/"
                + IntegerMath.toBigInteger(q.denominator).toString(radix);
        }
        return IntegerMath.toBigInteger(v).toString(radix);
    }

    private static void appendPart(StringBuilder sb, Object v, int radix) {
        if (v instanceof Double) sb.append(Value.formatDouble((double)(Double) v));
        else sb.append(exactString(v, radix));
    }

    private static void appendAbsImag(StringBuilder sb, Object v, int radix) {
        if (v instanceof Double) {
            double d = (double)(Double) v;
            if (Double.isNaN(d)) sb.append("nan.0");
            else if (Double.isInfinite(d)) sb.append("inf.0");
            else sb.append(Value.formatDouble(Math.abs(d)));
        } else {
            sb.append(exactString(partAbs(v), radix));
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

    // --- Transcendental functions (inexact, on doubles) ---

    // The real and imaginary part of a number as doubles.
    public static double re(Object z) {
        return z instanceof Complex ? partToDouble(((Complex) z).real) : partToDouble(z);
    }

    public static double im(Object z) {
        return z instanceof Complex ? partToDouble(((Complex) z).imag) : 0.0;
    }

    private static Object make(double[] z) { return new Complex(z[0], z[1]); }

    private static double[] cmul(double[] a, double[] b) {
        return new double[] { a[0] * b[0] - a[1] * b[1], a[0] * b[1] + a[1] * b[0] };
    }

    private static double[] cdiv(double[] a, double[] b) {
        double d = b[0] * b[0] + b[1] * b[1];
        return new double[] { (a[0] * b[0] + a[1] * b[1]) / d, (a[1] * b[0] - a[0] * b[1]) / d };
    }

    private static double[] cexp(double[] z) {
        double e = Math.exp(z[0]);
        if (z[1] == 0.0) return new double[] { e, z[1] };
        return new double[] { e * Math.cos(z[1]), e * Math.sin(z[1]) };
    }

    private static double[] clog(double[] z) {
        return new double[] { Math.log(Math.hypot(z[0], z[1])), Math.atan2(z[1], z[0]) };
    }

    private static double[] csqrt(double[] z) {
        double r = Math.hypot(z[0], z[1]);
        // the sign of the imaginary part, -0.0 positive: the branch cut is
        // continuous with quadrant II (R7RS; chibi's (sqrt -1.0-0.0i) => +i)
        double im = Math.sqrt((r - z[0]) / 2);
        return new double[] { Math.sqrt((r + z[0]) / 2), z[1] < 0 ? -im : im };
    }

    private static double[] csin(double[] z) {
        return new double[] { Math.sin(z[0]) * Math.cosh(z[1]), Math.cos(z[0]) * Math.sinh(z[1]) };
    }

    private static double[] ccos(double[] z) {
        return new double[] { Math.cos(z[0]) * Math.cosh(z[1]), -Math.sin(z[0]) * Math.sinh(z[1]) };
    }

    // asin z = -i log(iz + sqrt(1 - z^2)); the zero imaginary parts as
    // the exact 1 gives them (0 - 0.0 = 0.0), so that (asin 2) is
    // 1.57...-1.31...i
    private static double[] casin(double[] z) {
        double[] z2 = cmul(z, z);
        double[] s = csqrt(new double[] { 1.0 - z2[0], 0.0 - z2[1] });
        double[] l = clog(new double[] { s[0] - z[1], s[1] + z[0] });
        return new double[] { l[1], -l[0] };
    }

    private static double[] toPair(Object z) { return new double[] { re(z), im(z) }; }

    public static Object exp(Object z) { return make(cexp(toPair(z))); }
    public static Object log(Object z) { return make(clog(toPair(z))); }
    public static Object sqrt(Object z) { return make(csqrt(toPair(z))); }
    public static Object sin(Object z) { return make(csin(toPair(z))); }
    public static Object cos(Object z) { return make(ccos(toPair(z))); }
    public static Object tan(Object z) { double[] p = toPair(z); return make(cdiv(csin(p), ccos(p))); }
    public static Object asin(Object z) { return make(casin(toPair(z))); }

    // acos z = pi/2 - asin z
    public static Object acos(Object z) {
        double[] a = casin(toPair(z));
        return make(new double[] { Math.PI / 2 - a[0], -a[1] });
    }

    // atan z = (log(1 + iz) - log(1 - iz)) / 2i
    public static Object atan(Object z) {
        double[] p = toPair(z);
        double[] a = clog(new double[] { 1.0 - p[1], 0.0 + p[0] });
        double[] b = clog(new double[] { 1.0 + p[1], 0.0 - p[0] });
        double dr = a[0] - b[0], di = a[1] - b[1];
        // (dr + di i) / 2i = di/2 - (dr/2) i
        return make(new double[] { di / 2, -dr / 2 });
    }

    // z1^z2 = exp(z2 log z1), in polar form: |z1|^x2 e^(-y2 angle z1) at
    // the angle x2 angle z1 + y2 ln|z1| (so (expt -1 0.5) is
    // 6.123233995736766e-17+1.0i, the magnitude Math.pow(1.0, 0.5) = 1.0)
    public static Object pow(Object z1, Object z2) {
        double[] a = toPair(z1), b = toPair(z2);
        double r = Math.hypot(a[0], a[1]), at = Math.atan2(a[1], a[0]);
        double len = Math.pow(r, b[0]), phase = at * b[0];
        if (b[1] != 0.0) {
            len /= Math.exp(at * b[1]);
            phase += b[1] * Math.log(r);
        }
        return make(new double[] { len * Math.cos(phase), len * Math.sin(phase) });
    }
}
