package scheme.primitives;

import scheme.*;

public class PrimitiveFirst extends Primitive {
    @Override
    public String name() {
        return "first";
    }

    @Override
    public String info() {
        return "Syntax: (first lst)\n" +
               "Library: (srfi 1)\n" +
               "Description: Returns the first element of list lst. Equivalent to car.\n" +
               "Example:\n" +
               "  (first '(a b c)) => a";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.asPair(arguments[0]).car;
    }
}
