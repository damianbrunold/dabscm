package scheme.primitives;

import scheme.*;

public class PrimitivePrimitiveP extends Primitive {
    @Override
    public String name() {
        return "primitive?";
    }

    @Override
    public String info() {
        return "Syntax: (primitive? obj)\n" +
               "Library: (scm core)\n" +
               "Description: Returns #t if obj is a built-in primitive procedure, otherwise returns #f.\n" +
               "Example:\n" +
               "  (primitive? car) => #t\n" +
               "  (primitive? (lambda (x) x)) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isPrimitive(arguments[0]);
    }
}
