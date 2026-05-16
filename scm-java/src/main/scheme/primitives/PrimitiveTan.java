package scheme.primitives;

import scheme.*;

public class PrimitiveTan extends Primitive {
    @Override
    public String name() {
        return "tan";
    }

    @Override
    public String info() {
        return "Syntax: (tan z)\n" +
               "Library: (scheme inexact)\n" +
               "Description: Returns the trigonometric tangent of z, where z is in radians.\n" +
               "Example:\n" +
               "  (tan 0) => 0.0\n" +
               "  (tan (/ (* 3.14159265 1) 4)) => 1.0";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Math.tan(toReal(arguments[0]));
    }
}
