package scheme.primitives;

import scheme.*;

public class PrimitiveErrorObjectP extends Primitive {
    @Override
    public String name() { return "error-object?"; }

    @Override
    public String info() {
        return "Syntax: (error-object? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is an error object (as raised by error), otherwise returns #f.\n" +
               "Example:\n" +
               "  (guard (e (#t (error-object? e)))\n" +
               "    (error \"oops\")) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return arguments[0] instanceof ErrorObject ? Value.T : Value.F;
    }
}
