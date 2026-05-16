package scheme.primitives;

import scheme.*;

public class PrimitiveListP extends Primitive {
    @Override
    public String name() { return "list?"; }

    @Override
    public String info() {
        return "Syntax: (list? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is a proper list (a sequence of pairs terminated by the empty list), otherwise returns #f. Also detects circular lists.\n" +
               "Example:\n" +
               "  (list? '(a b c)) => #t\n" +
               "  (list? '(a . b)) => #f\n" +
               "  (list? '()) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        // Floyd's cycle detection (tortoise and hare)
        var hare = arguments[0];
        var tortoise = arguments[0];
        while (true) {
            if (!Value.isPair(hare) || hare == Value.NIL) return hare == Value.NIL;
            hare = Value.asPair(hare).cdr;
            if (!Value.isPair(hare) || hare == Value.NIL) return hare == Value.NIL;
            hare = Value.asPair(hare).cdr;
            tortoise = Value.asPair(tortoise).cdr;
            if (hare == tortoise) return false;
        }
    }
}
