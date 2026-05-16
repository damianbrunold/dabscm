package scheme.primitives;

import scheme.*;

public class PrimitiveCos extends Primitive {
    @Override
    public String name() {
        return "cos";
    }

    @Override
    public String info() {
        return "Syntax: (cos z)\n" +
               "Library: (scheme inexact)\n" +
               "Description: Returns the cosine of z. The argument is in radians.\n" +
               "Example:\n" +
               "  (cos 0.0) => 1.0\n" +
               "  (cos 3.141592653589793) => -1.0";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Math.cos(toReal(arguments[0]));
    }
}
