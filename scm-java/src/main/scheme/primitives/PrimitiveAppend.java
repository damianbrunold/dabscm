package scheme.primitives;

import scheme.*;

import java.util.List;
import java.util.ArrayList;

public class PrimitiveAppend extends Primitive {
    @Override
    public String name() {
        return "append";
    }

    @Override
    public String info() {
        return "Syntax: (append list1 ... obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a list consisting of the elements of the first list followed by the elements of the other lists. The last argument may be any object.\n" +
               "Example:\n" +
               "  (append '(x) '(y)) => (x y)\n" +
               "  (append '(a) '(b c d)) => (a b c d)\n" +
               "  (append '(a b) '() '(c)) => (a b c)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        if (arguments.length == 0) return Value.NIL;
        List<Object> result = new ArrayList<>();
        for (int i = 0; i < arguments.length - 1; i++) {
            Object pair = arguments[i];
            while (pair != Value.NIL) {
                result.add(Value.asPair(pair).car);
                pair = Value.asPair(pair).cdr;
            }
        }
        if (result.size() == 0) {
            return arguments[arguments.length - 1];
        } else {
            Pair list = (Pair) Pair.list(result.toArray());
            Pair last = list;
            while (last.cdr != Value.NIL) {
                last = Value.asPair(last.cdr);
            }
            last.cdr = arguments[arguments.length - 1];
            return list;
        }
    }
}
