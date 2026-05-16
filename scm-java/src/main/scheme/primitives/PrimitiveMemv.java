package scheme.primitives;

import scheme.*;

public class PrimitiveMemv extends Primitive {
    @Override
    public String name() {
        return "memv";
    }

    @Override
    public String info() {
        return "Syntax: (memv obj list)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the first sublist of list whose car is eqv? to obj, or #f if no such sublist exists.\n" +
               "Example:\n" +
               "  (memv 2 '(1 2 3)) => (2 3)\n" +
               "  (memv 5 '(1 2 3)) => #f";
    }

    //(define (memv x ls)
    //  (if (or (null? ls) (not (pair? ls)))
    //      #f
    //      (if (eqv? x (first ls))
    //          ls
    //          (memv x (cdr ls)))))
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        Object x = arguments[0];
        Object lst = arguments[1];
        while (lst != Value.NIL) {
            if (!Value.isPair(lst)) return false;
            Pair p = Value.asPair(lst);
            if (PrimitiveEqvP.eqv(x, p.car)) return p;
            lst = p.cdr;
        }
        return false;
    }
}
