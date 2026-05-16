package scheme.primitives;

import scheme.*;

public class PrimitiveSin extends Primitive {
    @Override
    public String name() {
        return "sin";
    }

    @Override
    public String info() {
        return "Syntax: (sin z)\n" +
               "Library: (scheme inexact)\n" +
               "Description: Returns the sine of z, where z is in radians. Returns an inexact result.\n" +
               "Example:\n" +
               "  (sin 0) => 0.0\n" +
               "  (sin (/ (acos -1) 2)) => 1.0";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Math.sin(toReal(arguments[0]));
    }
}
