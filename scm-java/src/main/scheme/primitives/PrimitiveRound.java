package scheme.primitives;

import scheme.*;
import java.math.BigDecimal;
import java.math.RoundingMode;

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
            double d = Math.rint(Value.asRational(arguments[0]).toDouble());
            if (d >= Long.MIN_VALUE && d <= Long.MAX_VALUE) return (long) d;
            return IntegerMath.normalize(new BigDecimal(d).setScale(0, RoundingMode.HALF_EVEN).toBigInteger());
        } else {
            double d = Math.rint(toReal(arguments[0]));
            if (d >= Long.MIN_VALUE && d <= Long.MAX_VALUE) {
                return d;
            }
            return IntegerMath.normalize(new BigDecimal(d).setScale(0, RoundingMode.HALF_EVEN).toBigInteger());
        }
    }
}
