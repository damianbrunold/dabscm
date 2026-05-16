package scheme.primitives;

import scheme.*;

public class PrimitivePairP extends Primitive {
    @Override
    public String name() {
        return "pair?";
    }

    @Override
    public String info() {
        return "Syntax: (pair? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is a pair, otherwise returns #f.\n" +
               "Example:\n" +
               "  (pair? '(a b c)) => #t\n" +
               "  (pair? '()) => #f\n" +
               "  (pair? '(a . b)) => #t\n" +
               "  (pair? 7) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isPair(arguments[0]);
    }
}
