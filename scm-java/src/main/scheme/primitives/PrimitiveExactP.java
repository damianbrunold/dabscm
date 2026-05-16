package scheme.primitives;

import scheme.*;

public class PrimitiveExactP extends Primitive {
    @Override
    public String name() {
        return "exact?";
    }

    @Override
    public String info() {
        return "Syntax: (exact? z)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if z is an exact number (integer or rational), otherwise returns #f.\n" +
               "Example:\n" +
               "  (exact? 1) => #t\n" +
               "  (exact? 1.0) => #f\n" +
               "  (exact? 1/3) => #t";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isComplex(arguments[0])) {
            Complex c = Value.asComplex(arguments[0]);
            return Complex.isExact(c.real) && Complex.isExact(c.imag);
        }
        return Value.isInteger(arguments[0]) || Value.isRational(arguments[0]);
    }
}
