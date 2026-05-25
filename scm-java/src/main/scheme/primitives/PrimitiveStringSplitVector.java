package scheme.primitives;

import scheme.*;

public class PrimitiveStringSplitVector extends Primitive {
    @Override
    public String name() {
        return "string-split-vector";
    }

    @Override
    public String info() {
        return "Syntax: (string-split-vector s pattern?)\n" +
               "Library: (scm string)\n" +
               "Description: Splits the string s at occurrences of the regular expression pattern and returns a vector of the resulting substrings. Defaults to splitting on whitespace.\n" +
               "Example:\n" +
               "  (string-split-vector \"a b c\") => #(\"a\" \"b\" \"c\")\n" +
               "  (string-split-vector \"a,b,c\" \",\") => #(\"a\" \"b\" \"c\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        String s = new String(Value.asString(arguments[0]));
        String regexp = "[ \\t\\r\\n]+";
        if (arguments.length > 1) regexp = new String(Value.asString(arguments[1]));
        String[] parts = PrimitiveStringSplit.getSplitPattern(regexp).split(s, -1);
        Object[] result = new Object[parts.length];
        for (int i = 0; i < parts.length; i++) result[i] = parts[i].toCharArray();
        return result;
    }
}
