package scheme.primitives;

import scheme.*;

public class PrimitiveNumequal extends Primitive {
    @Override
    public String name() {
        return "=";
    }

    @Override
    public String info() {
        return "Syntax: (= z1 z2 z3 ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if all arguments are numerically equal.\n" +
               "Example:\n" +
               "  (= 1 1 1) => #t\n" +
               "  (= 1 2) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, -1);
        if (hasComplex(arguments)) {
            Object current = arguments[0];
            for (int i = 1; i < arguments.length; i++) {
                if (!Complex.numericEquals(current, arguments[i])) return false;
                current = arguments[i];
            }
            return true;
        }
        Object current = arguments[0];
        for (int i = 1; i < arguments.length; i++) {
            Object next = arguments[i];
            if (Value.isInteger(current) && Value.isInteger(next)) {
                if (!IntegerMath.genericEquals(current, next)) return false;
            } else if (Value.isReal(current) && Value.isReal(next)) {
                if (!Value.asReal(current).equals(Value.asReal(next)) || Double.isNaN(Value.asReal(current))) return false;
            } else {
                // Mixed exact/inexact: convert inexact to exact for precise comparison
                if (!mixedNumericEquals(current, next)) return false;
            }
            current = next;
        }
        return true;
    }
}
