package scheme.primitives;

import scheme.*;

public class PrimitiveVector extends Primitive {
    @Override
    public String name() {
        return "vector";
    }

    @Override
    public String info() {
        return "Syntax: (vector obj ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a newly allocated vector whose elements contain the given arguments.\n" +
               "Example:\n" +
               "  (vector 1 2 3) => #(1 2 3)\n" +
               "  (vector 'a 'b 'c) => #(a b c)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        Object[] result = new Object[arguments.length];
        System.arraycopy(arguments, 0, result, 0, arguments.length);
        return result;
    }
}
