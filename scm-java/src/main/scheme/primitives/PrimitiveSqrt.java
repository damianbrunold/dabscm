package scheme.primitives;

import scheme.*;

public class PrimitiveSqrt extends Primitive {
    @Override
    public String name() {
        return "sqrt";
    }

    @Override
    public String info() {
        return "Syntax: (sqrt z)\n" +
               "Library: (scheme inexact)\n" +
               "Description: Returns the principal square root of z. Returns an exact integer when the result is an exact integer, otherwise returns an inexact number.\n" +
               "Example:\n" +
               "  (sqrt 4) => 2\n" +
               "  (sqrt 2) => 1.4142135623730951\n" +
               "  (sqrt 9) => 3";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        Object z = arguments[0];
        if (Value.isComplex(z)) return Complex.sqrt(z);
        if (Value.isInteger(z) || Value.isRational(z)) {
            Object r = exactSqrt(z);
            if (r != null) return r;
        }
        double val = toReal(z);
        if (val < 0) {
            return Complex.create(0.0, inexactSqrt(Complex.partNegate(z)));
        }
        return inexactSqrt(z);
    }

    // The square root of an exact non-negative number when it is exact (a
    // perfect square of numerator and denominator), else null.
    public static Object exactSqrt(Object z) {
        if (Value.isRational(z)) {
            Rational q = Value.asRational(z);
            Object n = exactSqrt(q.numerator);
            if (n == null) return null;
            Object d = exactSqrt(q.denominator);
            if (d == null) return null;
            return Rational.create(n, d);
        }
        java.math.BigInteger b = IntegerMath.toBigInteger(z);
        if (b.signum() < 0) return null;
        java.math.BigInteger s = b.sqrt();
        return s.multiply(s).equals(b) ? IntegerMath.normalize(s) : null;
    }

    // The square root of a non-negative real as a double (a huge exact
    // integer whose double is infinite through its integer square root).
    private double inexactSqrt(Object z) {
        double d = toReal(z);
        if (Double.isInfinite(d) && Value.isInteger(z))
            return IntegerMath.toBigInteger(z).sqrt().doubleValue();
        return Math.sqrt(d);
    }
}
