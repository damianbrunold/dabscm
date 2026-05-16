package scheme.primitives;

import scheme.*;

public class PrimitiveCar extends Primitive {
    @Override
    public String name() {
        return "car";
    }

    @Override
    public String info() {
        return "Syntax: (car pair)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the car of pair. It is an error if pair is not a pair.\n" +
               "Example:\n" +
               "  (car '(a b c)) => a\n" +
               "  (car '((a) b)) => (a)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.asPair(arguments[0]).car;
    }
}
