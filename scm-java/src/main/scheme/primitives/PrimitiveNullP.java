package scheme.primitives;

import scheme.*;

public class PrimitiveNullP extends Primitive {
    @Override
    public String name() {
        return "null?";
    }

    @Override
    public String info() {
        return "Syntax: (null? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is the empty list '(), otherwise returns #f.\n" +
               "Example:\n" +
               "  (null? '()) => #t\n" +
               "  (null? '(1 2)) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return arguments[0] == Value.NIL;
    }
}
