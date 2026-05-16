package scheme.primitives;

import scheme.*;

import java.util.Arrays;

public class PrimitiveMakeVector extends Primitive {
    @Override
    public String name() {
        return "make-vector";
    }

    @Override
    public String info() {
        return "Syntax: (make-vector k) (make-vector k fill)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a newly allocated vector of k elements. If fill is given, every element is initialized to fill; otherwise each element is 0.\n" +
               "Example:\n" +
               "  (make-vector 3 0) => #(0 0 0)\n" +
               "  (make-vector 3 'a) => #(a a a)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        int n = IntegerMath.toInt(arguments[0]);
        Object obj = 0;
        if (arguments.length == 2) obj = arguments[1];

        Object[] result = new Object[n];
        Arrays.fill(result, obj);
        return result;
    }
}
