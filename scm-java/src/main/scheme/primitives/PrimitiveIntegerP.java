package scheme.primitives;

import scheme.*;

public class PrimitiveIntegerP extends Primitive {
    @Override
    public String name() {
        return "integer?";
    }

    @Override
    public String info() {
        return "Syntax: (integer? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is an integer (exact or inexact with an integer value), otherwise returns #f.\n" +
               "Example:\n" +
               "  (integer? 1) => #t\n" +
               "  (integer? 1.0) => #t\n" +
               "  (integer? 1.5) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isInteger(arguments[0])) return Value.T;
        if (Value.isReal(arguments[0])) {
            double val = toReal(arguments[0]);
            return val == (double) ((long) val) ? Value.T : Value.F;
        }
        return Value.F;
    }
}
