package scheme.primitives;

import scheme.*;

public class PrimitiveVectorRef extends Primitive {
    @Override
    public String name() {
        return "vector-ref";
    }

    @Override
    public String info() {
        return "Syntax: (vector-ref v k)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the element at index k in vector v. If k is out of range and a default is provided, returns the default instead of signalling an error.\n" +
               "Example:\n" +
               "  (vector-ref #(a b c) 1) => b\n" +
               "  (vector-ref #(a b c) 5 'none) => none";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 3);
        Object[] v = Value.asVector(arguments[0]);
        int idx = IntegerMath.toInt(arguments[1]);
        if (idx >= v.length && arguments.length == 3) {
            return arguments[2];
        } else {
            return v[idx];
        }
    }
}
