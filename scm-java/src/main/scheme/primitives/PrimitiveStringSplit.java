package scheme.primitives;

import scheme.*;

import java.util.List;
import java.util.ArrayList;

public class PrimitiveStringSplit extends Primitive {
    @Override
    public String name() {
        return "string-split";
    }

    @Override
    public String info() {
        return "Syntax: (string-split s pattern?)\n" +
               "Library: (scm string)\n" +
               "Description: Splits the string s at occurrences of the regular expression pattern and returns a list of the resulting substrings. Defaults to splitting on whitespace.\n" +
               "Example:\n" +
               "  (string-split \"a b c\") => (\"a\" \"b\" \"c\")\n" +
               "  (string-split \"a,b,c\" \",\") => (\"a\" \"b\" \"c\")";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        String s = new String(Value.asString(arguments[0]));
        String regexp = "[ \\t\\r\\n]+";
        if (arguments.length > 1) regexp = new String(Value.asString(arguments[1]));
        String[] parts = s.split(regexp, -1);
        List<char[]> result = new ArrayList<>();
        for (String part : parts) result.add(part.toCharArray());
        return Pair.list(result.toArray());
    }
}
