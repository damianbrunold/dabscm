package scheme.primitives;

import scheme.*;

public class PrimitiveCeiling extends Primitive {

    @Override
    public String name() {
        return "ceiling";
    }

    @Override
    public String info() {
        return "Syntax: (ceiling z)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the smallest integer not smaller than z (rounds toward positive infinity).\n" +
               "Example:\n" +
               "  (ceiling 1.2) => 2.0\n" +
               "  (ceiling -1.2) => -1.0\n" +
               "  (ceiling 3) => 3";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        if (arguments.length != 1) throw new SchemeError(pos, "ceiling", "expected 1 argument, but got " + arguments.length);
        if (Value.isInteger(arguments[0])) {
            return arguments[0];
        } else if (Value.isRational(arguments[0])) {
            return Value.asRational(arguments[0]).ceiling();
        } else {
            // stays inexact; also for infinities, NaN and beyond the long range
            double d = toReal(arguments[0]);
            return Math.ceil(d);
        }
    }

}
