package scheme.primitives;

import scheme.*;

public class PrimitiveCons extends Primitive {
    @Override
    public String name() {
        return "cons";
    }

    @Override
    public String info() {
        return "Syntax: (cons obj1 obj2)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a newly allocated pair whose car is obj1 and whose cdr is obj2.\n" +
               "Example:\n" +
               "  (cons 'a '()) => (a)\n" +
               "  (cons 'a '(b c)) => (a b c)\n" +
               "  (cons 1 2) => (1 . 2)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        return new Pair(arguments[0], arguments[1]);
    }
}
