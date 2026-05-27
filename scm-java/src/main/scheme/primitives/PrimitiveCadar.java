package scheme.primitives;

import scheme.*;

public class PrimitiveCadar extends Primitive {
    @Override
    public String name() {
        return "cadar";
    }

    @Override
    public String info() {
        return "Syntax: (cadar pair)\n" +
               "Library: (scheme cxr)\n" +
               "Description: Returns the car of the cdr of the car of pair. Equivalent to (car (cdr (car pair))).\n" +
               "Example:\n" +
               "  (cadar '((a b) c)) => b";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.asPair(Value.asPair(Value.asPair(arguments[0]).car).cdr).car;
    }
}
