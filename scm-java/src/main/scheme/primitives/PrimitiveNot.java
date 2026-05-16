package scheme.primitives;

import scheme.*;

public class PrimitiveNot extends Primitive {
    @Override
    public String name() {
        return "not";
    }

    @Override
    public String info() {
        return "Syntax: (not obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is #f, otherwise returns #f.\n" +
               "Example:\n" +
               "  (not #f) => #t\n" +
               "  (not #t) => #f\n" +
               "  (not 42) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (arguments[0].equals(Value.F)) return Value.T;
        else return Value.F;
    }
}
