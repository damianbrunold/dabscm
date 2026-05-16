package scheme.primitives;

import scheme.*;

public class PrimitiveMemq extends Primitive {
    @Override
    public String name() {
        return "memq";
    }

    @Override
    public String info() {
        return "Syntax: (memq obj list)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the first sublist of list whose car is eq? to obj, or #f if no such sublist exists.\n" +
               "Example:\n" +
               "  (memq 'b '(a b c)) => (b c)\n" +
               "  (memq 'z '(a b c)) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        var val = arguments[0];
        var lst = arguments[1];
        while (lst != Value.NIL) {
            if (!Value.isPair(lst)) return Value.F;
            if (val.equals(Value.asPair(lst).car)) return lst;
            lst = Value.asPair(lst).cdr;
        }
        return Value.F;
    }
}
