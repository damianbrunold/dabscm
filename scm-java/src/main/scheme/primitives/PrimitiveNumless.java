package scheme.primitives;

import scheme.*;

public class PrimitiveNumless extends Primitive {
    @Override
    public String name() {
        return "<";
    }

    @Override
    public String info() {
        return "Syntax: (< z1 z2 z3 ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if the arguments are monotonically increasing.\n" +
               "Example:\n" +
               "  (< 1 2 3) => #t\n" +
               "  (< 1 1) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, -1);
        if (hasComplex(arguments))
            throw new SchemeError(pos, "<: not applicable to complex numbers");
        Object current = arguments[0];
        for (int i = 1; i < arguments.length; i++) {
            Object next = arguments[i];
            if (Value.isInteger(current) && Value.isInteger(next)) {
                if (IntegerMath.compare(current, next) >= 0) return false;
            } else if (Value.isReal(current) && Value.isReal(next)) {
                if (Value.asReal(current) >= Value.asReal(next)) return false;
            } else {
                if (mixedNumericCompare(current, next) >= 0) return false;
            }
            current = next;
        }
        return true;
    }
}
