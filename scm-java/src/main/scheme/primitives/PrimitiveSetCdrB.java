package scheme.primitives;

import scheme.*;

public class PrimitiveSetCdrB extends Primitive {
    @Override
    public String name() {
        return "set-cdr!";
    }

    @Override
    public String info() {
        return "Syntax: (set-cdr! pair obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Stores obj in the cdr field of pair. It is an error if pair is not a pair.\n" +
               "Example:\n" +
               "  (define p (list 1 2 3))\n" +
               "  (set-cdr! p '(b c))\n" +
               "  p => (1 b c)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        Value.asPair(arguments[0]).cdr = arguments[1];
        return new Values();
    }
}
