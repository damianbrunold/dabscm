package scheme.primitives;

import scheme.*;

public class PrimitiveVectorLength extends Primitive {
    @Override
    public String name() {
        return "vector-length";
    }

    @Override
    public String info() {
        return "Syntax: (vector-length v)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the number of elements in vector v.\n" +
               "Example:\n" +
               "  (vector-length #(1 2 3)) => 3\n" +
               "  (vector-length (vector)) => 0";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return (long) Value.asVector(arguments[0]).length;
    }
}
