package scheme.primitives;

import scheme.*;

public class PrimitiveCadr extends Primitive {
    @Override
    public String name() {
        return "cadr";
    }

    @Override
    public String info() {
        return "Syntax: (cadr pair)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the car of the cdr of pair. Equivalent to (car (cdr pair)).\n" +
               "Example:\n" +
               "  (cadr '(a b c)) => b";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.asPair(Value.asPair(arguments[0]).cdr).car;
    }
}
