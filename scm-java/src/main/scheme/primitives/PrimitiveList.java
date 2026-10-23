package scheme.primitives;

import scheme.*;

public class PrimitiveList extends Primitive {
    @Override
    public String name() {
        return "list";
    }

    @Override
    public String info() {
        return "Syntax: (list obj ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a newly allocated list of its arguments.\n" +
               "Example:\n" +
               "  (list 'a (+ 3 4) 'c) => (a 7 c)\n" +
               "  (list) => ()";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        Object result = Value.NIL;
        for (int i = arguments.length - 1; i >= 0; i--)
            result = new Pair(arguments[i], result);
        return result;
    }
}
