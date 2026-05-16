package scheme.primitives;

import scheme.*;

public class PrimitiveStringPrefixP extends Primitive {
    @Override
    public String name() {
        return "string-prefix?";
    }

    @Override
    public String info() {
        return "Syntax: (string-prefix? prefix s)\n" +
               "Library: (srfi 13)\n" +
               "Description: Returns #t if prefix is a prefix of s, otherwise returns #f.\n" +
               "Example:\n" +
               "  (string-prefix? \"hel\" \"hello\") => #t\n" +
               "  (string-prefix? \"world\" \"hello\") => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        char[] prefix = Value.asString(arguments[0]);
        char[] str = Value.asString(arguments[1]);
        if (prefix.length > str.length) {
            return false;
        }
        var i = 0;
        while (i < prefix.length) {
            if (str[i] != prefix[i]) return false;
            i++;
        }
        return true;
    }
}
