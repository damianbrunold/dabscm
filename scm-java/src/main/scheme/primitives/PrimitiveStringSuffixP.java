package scheme.primitives;

import scheme.*;

public class PrimitiveStringSuffixP extends Primitive {
    @Override
    public String name() {
        return "string-suffix?";
    }

    @Override
    public String info() {
        return "Syntax: (string-suffix? suffix s)\n" +
               "Library: (srfi 13)\n" +
               "Description: Returns #t if suffix is a suffix of s, otherwise returns #f.\n" +
               "Example:\n" +
               "  (string-suffix? \"lo\" \"hello\") => #t\n" +
               "  (string-suffix? \"hi\" \"hello\") => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        char[] suffix = Value.asString(arguments[0]);
        char[] str = Value.asString(arguments[1]);
        if (suffix.length > str.length) {
            return false;
        }
        var i = suffix.length - 1;
        var j = str.length - 1;
        while (i >= 0) {
            if (str[j] != suffix[i]) return false;
            i--;
            j--;
        }
        return true;
    }
}
