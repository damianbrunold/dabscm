package scheme.primitives;

import scheme.*;

public class PrimitiveAssv extends Primitive {
    @Override
    public String name() {
        return "assv";
    }

    @Override
    public String info() {
        return "Syntax: (assv key alist)\n" +
               "Library: (scheme base)\n" +
               "Description: Searches association list alist for a pair whose car is eqv? to key. Returns the first matching pair, or #f if none is found.\n" +
               "Example:\n" +
               "  (assv 2 '((1 a) (2 b) (3 c))) => (2 b)\n" +
               "  (assv 5 '((1 a) (2 b))) => #f";
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
            if (PrimitiveEqvP.eqv(x, entry.car)) return entry;
            lst = p.cdr;
        }
        return false;
    }
}
