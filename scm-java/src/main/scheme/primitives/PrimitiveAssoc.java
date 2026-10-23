package scheme.primitives;

import scheme.*;

public class PrimitiveAssoc extends Primitive {
    @Override
    public String name() {
        return "assoc";
    }

    @Override
    public String info() {
        return "Syntax: (assoc key alist)\n" +
               "Library: (scheme base)\n" +
               "Description: Searches association list alist for a pair whose car is equal? to key. Returns the first matching pair, or #f if none is found.\n" +
               "Example:\n" +
               "  (assoc \"b\" '((\"a\" 1) (\"b\" 2))) => (\"b\" 2)";
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
            if (PrimitiveEqualP.equal(x, entry.car)) return entry;
            lst = p.cdr;
        }
        return false;
    }
}
