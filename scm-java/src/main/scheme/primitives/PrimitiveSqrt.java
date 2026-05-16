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
        if (Value.isComplex(arguments[0])) {
            Complex c = Value.asComplex(arguments[0]);
            double a = Complex.partToDouble(c.real);
            double b = Complex.partToDouble(c.imag);
            double mag = Math.sqrt(a * a + b * b);
            double newReal = Math.sqrt((mag + a) / 2.0);
            double newImag = (b >= 0 ? 1 : -1) * Math.sqrt((mag - a) / 2.0);
            return Complex.create(newReal, newImag);
        }
        double val = toReal(arguments[0]);
        if (val < 0) {
            return Complex.create(0.0, Math.sqrt(-val));
        }
        double result = Math.sqrt(val);
        if (Value.isInteger(arguments[0]) && result == (double) ((long) result)) return (long) result;
        return result;
    }
}
