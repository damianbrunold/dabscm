package scheme.primitives;

import scheme.*;

public class PrimitiveListRef extends Primitive {
    @Override
    public String name() {
        return "list-ref";
    }

    @Override
    public String info() {
        return "Syntax: (list-ref list k)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the k-th element (zero-indexed) of list. It is an error if k is out of range.\n" +
               "Example:\n" +
               "  (list-ref '(a b c) 0) => a\n" +
               "  (list-ref '(a b c) 2) => c";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        // (define (list-ref ls n)
        //   (if (= n 0)
        //       (car ls)
        //       (list-ref (cdr ls) (- n 1))))

        checkArgs(pos, arguments, 2, 2);

        var head = Value.asPair(arguments[0]);
        var n = IntegerMath.toInt(arguments[1]);
        while (n > 0) {
            head = Value.asPair(head.cdr);
            n--;
        }
        return head.car;
    }
}
