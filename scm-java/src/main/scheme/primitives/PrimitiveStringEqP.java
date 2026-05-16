package scheme.primitives;

import scheme.*;

public class PrimitiveStringEqP extends Primitive {
    @Override
    public String name() {
        return "string=?";
    }

    @Override
    public String info() {
        return "Syntax: (string=? s1 s2 ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if all the given strings are equal to each other, otherwise returns #f.\n" +
               "Example:\n" +
               "  (string=? \"abc\" \"abc\") => #t\n" +
               "  (string=? \"abc\" \"def\") => #f\n" +
               "  (string=? \"x\" \"x\" \"x\") => #t";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, -1);
        char[] current = Value.asString(arguments[0]);
        for (int i = 1; i < arguments.length; i++) {
            char[] next = Value.asString(arguments[i]);
            //if (!(new String(Value.asString(current)).equals(new String(Value.asString(next))))) return false;
            if (current.length != next.length) return false;
            for (var idx = 0; idx < current.length; idx++) {
                if (current[idx] != next[idx]) return false;
            }
            //current = next;
        }
        return true;
    }
}
