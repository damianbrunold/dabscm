package scheme.primitives;

import scheme.*;

public class PrimitiveRound extends Primitive {
    @Override
    public String name() {
        return "round";
    }

    @Override
    public String info() {
        return "Syntax: (round z)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the integer closest to z. If z is halfway between two integers, rounds to the even one (banker's rounding).\n" +
               "Example:\n" +
               "  (round 3.5) => 4.0\n" +
               "  (round 2.5) => 2.0\n" +
               "  (round 7/2) => 4";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isInteger(arguments[0])) {
            return arguments[0];
        } else if (Value.isRational(arguments[0])) {
            return Value.asRational(arguments[0]).round();
        } else {
            // stays inexact; also for infinities, NaN and beyond the long range
            double d = toReal(arguments[0]);
            return Math.rint(d);
        }
    }
}
