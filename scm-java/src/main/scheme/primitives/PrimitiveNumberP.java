package scheme.primitives;

import scheme.*;

public class PrimitiveNumberP extends Primitive {
    @Override
    public String name() {
        return "number?";
    }

    @Override
    public String info() {
        return "Syntax: (number? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is a number (exact integer, rational, or inexact real), otherwise returns #f.\n" +
               "Example:\n" +
               "  (number? 3) => #t\n" +
               "  (number? 3.5) => #t\n" +
               "  (number? \"3\") => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isReal(arguments[0]) || Value.isInteger(arguments[0]) || Value.isRational(arguments[0]) || Value.isComplex(arguments[0]);
    }
}
