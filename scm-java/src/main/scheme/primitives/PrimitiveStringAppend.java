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
        StringBuilder result = new StringBuilder();
        for (Object argument : arguments) {
            result.append(Value.asString(argument));
        }
        return result.toString().toCharArray();
    }
}
