package scheme.primitives;

import scheme.*;

public class PrimitiveCdr extends Primitive {
    @Override
    public String name() {
        return "cdr";
    }

    @Override
    public String info() {
        return "Syntax: (cdr pair)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the cdr of pair. It is an error if pair is not a pair.\n" +
               "Example:\n" +
               "  (cdr '((a) b c)) => (b c)\n" +
               "  (cdr '(1 . 2)) => 2";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.asPair(arguments[0]).cdr;
    }
}
