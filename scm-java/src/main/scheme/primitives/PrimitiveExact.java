package scheme.primitives;

import scheme.*;

public class PrimitiveExact extends Primitive {
    @Override
    public String name() {
        return "exact";
    }

    @Override
    public String info() {
        return "Syntax: (exact z)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the exact number that is numerically equal to z.\n" +
               "  For an inexact z that is the exact value of the binary floating-point\n" +
               "  number (R7RS), so (exact 0.1) is 3602879701896397/36028797018963968;\n" +
               "  rationalize finds the simplest rational near it.\n" +
               "Example:\n" +
               "  (exact 1.5) => 3/2\n" +
               "  (exact 0.1) => 3602879701896397/36028797018963968\n" +
               "  (exact 3.0) => 3\n" +
               "  (exact 3) => 3";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isComplex(arguments[0])) {
            Complex c = Value.asComplex(arguments[0]);
            return Complex.create(Complex.toExact(c.real), Complex.toExact(c.imag));
        }
        if (Value.isInteger(arguments[0])) return arguments[0];
        if (Value.isRational(arguments[0])) return arguments[0];
        double d = Value.asReal(arguments[0]);
        if (Double.isNaN(d) || Double.isInfinite(d))
            throw new SchemeError(pos, "exact: no exact representation for ~a", arguments[0]);
        return Complex.toExact(d);
    }
}
