package scheme.primitives;

import scheme.*;

public class PrimitiveFloor extends Primitive {
    @Override
    public String name() {
        return "floor";
    }

    @Override
    public String info() {
        return "Syntax: (floor z)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the largest integer not larger than z (rounds toward negative infinity).\n" +
               "Example:\n" +
               "  (floor 1.8) => 1.0\n" +
               "  (floor -1.2) => -2.0\n" +
               "  (floor 3) => 3";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isInteger(arguments[0])) {
            return arguments[0];
        } else if (Value.isRational(arguments[0])) {
            return Value.asRational(arguments[0]).floor();
        } else {
            // stays inexact; also for infinities, NaN and beyond the long range
            double d = toReal(arguments[0]);
            return Math.floor(d);
        }
    }
}
