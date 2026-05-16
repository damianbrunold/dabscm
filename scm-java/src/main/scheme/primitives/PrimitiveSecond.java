package scheme.primitives;

import scheme.*;

public class PrimitiveSecond extends Primitive {
    @Override
    public String name() {
        return "second";
    }

    @Override
    public String info() {
        return "Syntax: (second list)\n" +
               "Library: (srfi 1)\n" +
               "Description: Returns the second element of a list. Equivalent to (cadr list).\n" +
               "Example:\n" +
               "  (second '(a b c)) => b\n" +
               "  (second '(1 2 3)) => 2";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.asPair(Value.asPair(arguments[0]).cdr).car;
    }
}
