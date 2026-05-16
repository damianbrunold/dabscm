package scheme.primitives;

import scheme.*;

public class PrimitiveLength extends Primitive {
    @Override
    public String name() {
        return "length";
    }

    @Override
    public String info() {
        return "Syntax: (length list)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the number of elements in the proper list. It is an error if the list is not a proper list.\n" +
               "Example:\n" +
               "  (length '(a b c)) => 3\n" +
               "  (length '()) => 0";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        // (define (length x)
        //   (let loop ((x x) (n 0))
        //     (if (null? x)
        // 	n
        // 	(loop (cdr x) (+ n 1)))))
        
        checkArgs(pos, arguments, 1, 1);
        
        var head = arguments[0];
        var result = 0;
        while (head != Value.NIL) {
            head = Value.asPair(head).cdr;
            result++;
        }
        return (long) result;
    }
}
