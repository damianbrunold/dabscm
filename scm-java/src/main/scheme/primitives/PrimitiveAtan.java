package scheme.primitives;

import scheme.*;

public class PrimitiveAtan extends Primitive {
    @Override
    public String name() {
        return "atan";
    }

    @Override
    public String info() {
        return "Syntax: (atan z) (atan y x)\n" +
               "Library: (scheme inexact)\n" +
               "Description: Returns the arc tangent of z, or of y/x when two arguments are given. The result is in radians.\n" +
               "Example:\n" +
               "  (atan 0.0) => 0.0\n" +
               "  (atan 1.0 1.0) => 0.7853981633974483";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        if (arguments.length == 1) return Math.atan(toReal(arguments[0]));
        return Math.atan2(toReal(arguments[0]), toReal(arguments[1]));
    }
}
