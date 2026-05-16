package scheme.primitives;

import scheme.*;

public class PrimitiveBooleanP extends Primitive {
    @Override
    public String name() {
        return "boolean?";
    }

    @Override
    public String info() {
        return "Syntax: (boolean? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is either #t or #f, otherwise returns #f.\n" +
               "Example:\n" +
               "  (boolean? #f) => #t\n" +
               "  (boolean? 0) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isBoolean(arguments[0]);
    }
}
