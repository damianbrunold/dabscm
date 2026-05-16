package scheme.primitives;

import scheme.*;

public class PrimitiveVectorP extends Primitive {
    @Override
    public String name() {
        return "vector?";
    }

    @Override
    public String info() {
        return "Syntax: (vector? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is a vector, #f otherwise.\n" +
               "Example:\n" +
               "  (vector? #(1 2 3)) => #t\n" +
               "  (vector? '(1 2 3)) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isVector(arguments[0]);
    }
}
