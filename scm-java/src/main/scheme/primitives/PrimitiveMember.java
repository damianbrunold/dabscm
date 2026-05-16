package scheme.primitives;

import scheme.*;

public class PrimitiveMember extends Primitive {
    @Override
    public String name() {
        return "member";
    }

    @Override
    public String info() {
        return "Syntax: (member obj list)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the first sublist of list whose car is equal? to obj, or #f if no such sublist exists.\n" +
               "Example:\n" +
               "  (member 'b '(a b c)) => (b c)\n" +
               "  (member 'd '(a b c)) => #f";
    }

    //(define (member x ls)
    //  (if (or (null? ls) (not (pair? ls)))
    //      #f
    //      (if (equal? x (first ls))
    //          ls
    //          (member x (cdr ls)))))
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        Object x = arguments[0];
        Object lst = arguments[1];
        while (lst != Value.NIL) {
            if (!Value.isPair(lst)) return false;
            Pair p = Value.asPair(lst);
            if (PrimitiveEqualP.equal(x, p.car)) return p;
            lst = p.cdr;
        }
        return false;
    }
}
