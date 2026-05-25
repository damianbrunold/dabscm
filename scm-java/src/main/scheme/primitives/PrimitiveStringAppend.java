package scheme.primitives;

import scheme.*;

public class PrimitiveStringAppend extends Primitive {
    @Override
    public String name() {
        return "string-append";
    }

    @Override
    public String info() {
        return "Syntax: (string-append string ...)\n" +
               "Library: (scheme base) (srfi 13)\n" +
               "Description: Returns a newly allocated string whose characters are the concatenation of the characters in the given strings.\n" +
               "Example:\n" +
               "  (string-append \"foo\" \"bar\") => \"foobar\"\n" +
               "  (string-append \"a\" \"b\" \"c\") => \"abc\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        int total = 0;
        char[][] parts = new char[arguments.length][];
        for (int i = 0; i < arguments.length; i++) {
            char[] part = Value.asString(arguments[i]);
            parts[i] = part;
            total += part.length;
        }
        char[] result = new char[total];
        int offset = 0;
        for (int i = 0; i < parts.length; i++) {
            char[] part = parts[i];
            System.arraycopy(part, 0, result, offset, part.length);
            offset += part.length;
        }
        return result;
    }
}
