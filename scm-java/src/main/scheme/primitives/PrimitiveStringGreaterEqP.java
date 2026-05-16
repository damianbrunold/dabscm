package scheme.primitives;

import scheme.*;

public class PrimitiveStringGreaterEqP extends Primitive {
    @Override
    public String name() {
        return "string>=?";
    }

    @Override
    public String info() {
        return "Syntax: (string>=? s1 s2 ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if the strings are monotonically non-decreasing in lexicographic order, otherwise returns #f.\n" +
               "Example:\n" +
               "  (string>=? \"b\" \"a\") => #t\n" +
               "  (string>=? \"abc\" \"abc\") => #t\n" +
               "  (string>=? \"a\" \"b\") => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, -1);
        Object current = arguments[0];
        for (int i = 1; i < arguments.length; i++) {
            Object next = arguments[i];
            int cmp = new String(Value.asString(current)).compareTo(new String(Value.asString(next)));
            if (!(cmp >= 0)) return false;
            current = next;
        }
        return true;
    }
}
