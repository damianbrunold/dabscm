package scheme.primitives;

import scheme.*;

public class PrimitiveStringIndexChar extends Primitive {
    @Override
    public String name() {
        return "%string-index-char";
    }

    @Override
    public String info() {
        return "Syntax: (%string-index-char s char)\n" +
               "Library: (srfi 13)\n" +
               "Description: Returns the index of the first occurrence of char in s, or #f. The fast path of string-index for a char without start/end.\n" +
               "Example:\n" +
               "  (%string-index-char \"hello\" #\\l) => 2";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        char[] s = Value.asString(arguments[0]);
        char c = Value.asChar(arguments[1]);
        for (int i = 0; i < s.length; i++)
            if (s[i] == c) return (long) i;
        return false;
    }
}
