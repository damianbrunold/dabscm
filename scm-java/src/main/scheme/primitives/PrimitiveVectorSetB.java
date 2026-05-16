package scheme.primitives;

import scheme.*;

public class PrimitiveVectorSetB extends Primitive {
    @Override
    public String name() {
        return "vector-set!";
    }

    @Override
    public String info() {
        return "Syntax: (vector-set! v k obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Stores obj in element k of vector v. It is an error if k is not a valid index of v.\n" +
               "Example:\n" +
               "  (let ((v (vector 1 2 3))) (vector-set! v 1 99) v) => #(1 99 3)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        Value.asVector(arguments[0])[(int) (long) arguments[1]] = arguments[2];
        return new Values();
    }
}
