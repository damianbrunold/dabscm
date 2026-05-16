package scheme.primitives;

import scheme.*;

public class PrimitiveLog extends Primitive {
    @Override
    public String name() {
        return "log";
    }

    @Override
    public String info() {
        return "Syntax: (log z) (log z base)\n" +
               "Library: (scheme inexact)\n" +
               "Description: Returns the natural logarithm of z, or the logarithm of z to base if given.\n" +
               "Example:\n" +
               "  (log 1.0) => 0.0\n" +
               "  (log 8.0 2.0) => 3.0";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        if (arguments.length == 2)
            return Math.log(toReal(arguments[0])) / Math.log(toReal(arguments[1]));
        return Math.log(toReal(arguments[0]));
    }
}
