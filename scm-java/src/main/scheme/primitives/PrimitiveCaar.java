package scheme.primitives;

import scheme.*;

public class PrimitiveCaar extends Primitive {
    @Override
    public String name() {
        return "caar";
    }

    @Override
    public String info() {
        return "Syntax: (caar pair)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the car of the car of pair. Equivalent to (car (car pair)).\n" +
               "Example:\n" +
               "  (caar '((a b) c)) => a";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.asPair(Value.asPair(arguments[0]).car).car;
    }
}
