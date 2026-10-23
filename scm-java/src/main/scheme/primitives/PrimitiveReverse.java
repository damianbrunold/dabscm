package scheme.primitives;

import scheme.*;

public class PrimitiveReverse extends Primitive {
    @Override
    public String name() {
        return "reverse";
    }

    @Override
    public String info() {
        return "Syntax: (reverse list)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a newly allocated list containing the elements of list in reverse order.\n" +
               "Example:\n" +
               "  (reverse '(1 2 3)) => (3 2 1)\n" +
               "  (reverse '()) => ()";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        Object lst = arguments[0];
        Object acc = Value.NIL;
        while (lst != Value.NIL) {
            Pair p = Value.asPair(lst);
            acc = new Pair(p.car, acc);
            lst = p.cdr;
        }
        return acc;
    }
}
