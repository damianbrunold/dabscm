package scheme.primitives;

import scheme.*;

public class PrimitiveInexact extends Primitive {
    @Override
    public String name() {
        return "inexact";
    }

    @Override
    public String info() {
        return "Syntax: (inexact z)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the inexact (floating-point) number that is numerically closest to z.\n" +
               "Example:\n" +
               "  (inexact 1) => 1.0\n" +
               "  (inexact 1/3) => 0.3333333333333333";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isComplex(arguments[0])) {
            Complex c = Value.asComplex(arguments[0]);
            return Complex.create(Complex.toInexact(c.real), Complex.toInexact(c.imag));
        }
        if (Value.isReal(arguments[0])) return arguments[0];
        if (Value.isRational(arguments[0])) return Value.asRational(arguments[0]).toDouble();
        if (Value.isBigInteger(arguments[0])) return IntegerMath.toDouble(arguments[0]);
        return (double) (long) Value.asInteger(arguments[0]);
    }
}
