package scheme.primitives;

import scheme.*;

public class PrimitiveGetProperty extends Primitive {
    //(define (get-property obj name)
    //  (let loop ((obj obj))
    //    (if (null? obj)
    //        #f
    //        (if (pair? (car obj))
    //            (if (eq? (caar obj) name)
    //                (cadar obj)
    //                (loop (cdr obj)))
    //            (if (eq? (car obj) name)
    //                name
    //                (loop (cdr obj)))))))

    @Override
    public String name() {
        return "get-property";
    }

    @Override
    public String info() {
        return "Syntax: (get-property lst name) (get-property lst name default)\n" +
               "Library: (scm core)\n" +
               "Description: Searches for name in the property list lst. Each element may be a symbol (flag) or a (name value) pair. Returns the value, the symbol itself (for flags), or default/#f if not found.\n" +
               "Example:\n" +
               "  (get-property '((x 1) (y 2)) 'x) => 1\n" +
               "  (get-property '(foo bar) 'foo) => foo";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 3);
        var lst = arguments[0];
        var val = arguments[1];
        var result = getProperty(lst, val, Value.F);
        if (result.equals(Value.F) && arguments.length == 3) {
            return arguments[2];
        }
        return result;
    }

    public static Object getProperty(Object lst, Object name, Object defaultvalue) {
        while (lst != Value.NIL) {
            var cur = Value.asPair(lst);
            if (Value.isPair(cur.car)) {
                Pair sub = Value.asPair(cur.car);
                if (sub.car.equals(name)) {
                    return Value.asPair(sub.cdr).car;
                }
            } else {
                if (cur.car.equals(name)) {
                    return cur.car;
                }
            }
            lst = cur.cdr;
        }
        return defaultvalue;
    }
}
