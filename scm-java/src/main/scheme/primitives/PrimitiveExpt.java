package scheme.primitives;

import scheme.*;

public class PrimitiveExpt extends Primitive {
    @Override
    public String name() {
        return "expt";
    }

    @Override
    public String info() {
        return "Syntax: (expt z1 z2)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns z1 raised to the power z2. If z2 is exact 0, returns exact 1.\n" +
               "Example:\n" +
               "  (expt 2 10) => 1024\n" +
               "  (expt 4 0) => 1\n" +
               "  (expt 2.0 3) => 8.0";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        Object z1 = arguments[0], z2 = arguments[1];
        if (!isNumber(z1)) throw new WrongTypeException(z1, "number");
        if (!isNumber(z2)) throw new WrongTypeException(z2, "number");
        if (Value.isInteger(z2)) {
            // an exact integer power
            if (z1 instanceof Double) {
                if (IntegerMath.isZero(z2)) return 1.0;
                return Math.pow((Double) z1, IntegerMath.toDouble(z2));
            }
            long b = IntegerMath.toLong(z2);
            if (b == 0) return Complex.isExact(z1) || isExactComplex(z1) ? (Object) 1L : (Object) 1.0;
            if (Value.isInteger(z1)) {
                if (b > 0) return IntegerMath.expt(z1, b);
                if (IntegerMath.isZero(z1)) throw new SchemeError(pos, "/: Division by zero");
                return Rational.div(1L, IntegerMath.expt(z1, -b));
            }
            if (Value.isRational(z1)) {
                Rational q = Value.asRational(z1);
                long e = Math.abs(b);
                Object n = IntegerMath.expt(q.numerator, e), d = IntegerMath.expt(q.denominator, e);
                return b > 0 ? Rational.create(n, d) : Rational.create(d, n);
            }
            // a complex number: repeated squaring
            Object r = 1L, sq = z1;
            long e = b == Long.MIN_VALUE ? Long.MAX_VALUE : Math.abs(b);
            while (e != 0) {
                if ((e & 1) != 0) r = Complex.mul(r, sq);
                e >>= 1;
                if (e != 0) sq = Complex.mul(sq, sq);
            }
            return b > 0 ? r : Complex.div(1L, r);
        }
        boolean inexact = !Complex.isExact(z1) && !isExactComplex(z1) || !Complex.isExact(z2) && !isExactComplex(z2);
        if (isZero(z1)) {
            if (isZero(z2)) return 1.0;
            if (Complex.re(z2) > 0) return inexact ? (Object) 0.0 : (Object) 0L;
            throw new SchemeError(pos, "/: Division by zero");
        }
        if (!(z1 instanceof Complex) && !(z2 instanceof Complex)) {
            double a = toReal(z1);
            double b = toReal(z2);
            if (b == 0.0) return 1.0;
            // a negative base to a non-integer power: the principal complex value
            if (a < 0 && b != Math.rint(b) && !Double.isInfinite(b)) return Complex.pow(a, b);
            return Math.pow(a, b);
        }
        // (exp z) is (expt E z)
        if (z1 instanceof Double && (Double) z1 == Math.E) return Complex.exp(z2);
        return Complex.pow(z1, z2);
    }

    private static boolean isNumber(Object z) {
        return z instanceof Long || z instanceof Double || z instanceof java.math.BigInteger
            || z instanceof Rational || z instanceof Complex;
    }

    private static boolean isExactComplex(Object z) {
        return z instanceof Complex && Complex.isExact(((Complex) z).real);
    }

    private static boolean isZero(Object z) {
        if (z instanceof Complex) {
            Complex c = (Complex) z;
            return Complex.partToDouble(c.real) == 0.0 && Complex.partToDouble(c.imag) == 0.0;
        }
        if (z instanceof Double) return (Double) z == 0.0;
        if (Value.isInteger(z)) return IntegerMath.isZero(z);
        return false;
    }
}
