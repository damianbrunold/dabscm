package scheme.primitives;

import scheme.*;

public class PrimitiveEqP extends Primitive {
    @Override
    public String name() {
        return "eq?";
    }

    @Override
    public String info() {
        return "Syntax: (eq? obj1 obj2)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj1 and obj2 are the same object. Equivalent to pointer equality for most types.\n" +
               "Example:\n" +
               "  (eq? 'a 'a) => #t\n" +
               "  (eq? '() '()) => #t\n" +
               "  (eq? (list 1) (list 1)) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        return eq(arguments[0], arguments[1]);
    }

    public static boolean eq(Object a, Object b) {
        return a == b;
    }

}
