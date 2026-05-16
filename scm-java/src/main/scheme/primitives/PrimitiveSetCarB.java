package scheme.primitives;

import scheme.*;

public class PrimitiveSetCarB extends Primitive {
    @Override
    public String name() {
        return "set-car!";
    }

    @Override
    public String info() {
        return "Syntax: (set-car! pair obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Stores obj in the car field of pair. It is an error if pair is not a pair.\n" +
               "Example:\n" +
               "  (define p (list 1 2 3))\n" +
               "  (set-car! p 'a)\n" +
               "  p => (a 2 3)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        Value.asPair(arguments[0]).car = arguments[1];
        return new Values();
    }
}
