package scheme.primitives;

import scheme.*;

public class PrimitiveAssq extends Primitive {
    @Override
    public String name() {
        return "assq";
    }

    @Override
    public String info() {
        return "Syntax: (assq key alist)\n" +
               "Library: (scheme base)\n" +
               "Description: Searches association list alist for a pair whose car is eq? to key. Returns the first matching pair, or #f if none is found.\n" +
               "Example:\n" +
               "  (assq 'b '((a 1) (b 2) (c 3))) => (b 2)\n" +
               "  (assq 'd '((a 1) (b 2))) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        Object x = arguments[0];
        Object lst = arguments[1];
        while (lst != Value.NIL) {
            if (!Value.isPair(lst)) return false;
            Pair p = Value.asPair(lst);
            Pair entry = Value.asPair(p.car);
            if (PrimitiveEqP.eq(x, entry.car)) return entry;
            lst = p.cdr;
        }
        return false;
    }
}
