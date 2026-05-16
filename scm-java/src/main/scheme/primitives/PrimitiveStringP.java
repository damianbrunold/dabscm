package scheme.primitives;

import scheme.*;

public class PrimitiveStringP extends Primitive {
    @Override
    public String name() {
        return "string?";
    }

    @Override
    public String info() {
        return "Syntax: (string? obj)\n" +
               "Library: (scheme base) (srfi 13)\n" +
               "Description: Returns #t if obj is a string, otherwise returns #f.\n" +
               "Example:\n" +
               "  (string? \"hello\") => #t\n" +
               "  (string? 42) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isString(arguments[0]);
    }
}
