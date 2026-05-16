package scheme.primitives;

import scheme.*;

public class PrimitiveRealP extends Primitive {
    @Override
    public String name() {
        return "real?";
    }

    @Override
    public String info() {
        return "Syntax: (real? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is a real number, otherwise returns #f. Integers and rationals are also real numbers.\n" +
               "Example:\n" +
               "  (real? 3) => #t\n" +
               "  (real? 3.5) => #t\n" +
               "  (real? 1/3) => #t\n" +
               "  (real? \"hello\") => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isReal(arguments[0]) || Value.isInteger(arguments[0]) || Value.isRational(arguments[0]);
    }
}
