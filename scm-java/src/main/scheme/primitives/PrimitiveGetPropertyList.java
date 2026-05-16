package scheme.primitives;

import scheme.*;

public class PrimitiveGetPropertyList extends Primitive {
    //(define (get-property-list obj name)
    //  (let loop ((obj obj))
    //    (if (null? obj)
    //        #f
    //        (if (pair? (car obj))
    //            (if (eq? (caar obj) name)
    //                (cdar obj)
    //                (loop (cdr obj)))
    //            (loop (cdr obj))))))

    @Override
    public String name() {
        return "get-property-list";
    }

    @Override
    public String info() {
        return "Syntax: (get-property-list lst name) (get-property-list lst name default)\n" +
               "Library: (scm core)\n" +
               "Description: Searches for name in the property list lst. Returns the cdr of the matching pair (the full value list), or default/#f if not found.\n" +
               "Example:\n" +
               "  (get-property-list '((x 1 2) (y 3)) 'x) => (1 2)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 3);
        var lst = arguments[0];
        var val = arguments[1];
        while (lst != Value.NIL) {
            Pair pair = Value.asPair(lst);
            if (Value.isPair(pair.car)) {
                Pair sub = Value.asPair(pair.car);
                if (sub.car.equals(val)) {
                    return sub.cdr;
                }
            } else {
                if (pair.car.equals(val)) {
                    return pair.car;
                }
            }
            lst = pair.cdr;
        }
        if (arguments.length == 3) return arguments[2];
        return Value.F;
    }
}
