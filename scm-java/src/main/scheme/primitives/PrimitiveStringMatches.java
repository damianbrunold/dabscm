
package scheme.primitives;

import scheme.*;

import java.util.regex.*;

public class PrimitiveStringMatches extends Primitive {
    @Override
    public String name() {
        return "string-matches";
    }

    @Override
    public String info() {
        return "Syntax: (string-matches s pattern)\n" +
               "Library: (scm string)\n" +
               "Description: Matches the string s against the regular expression pattern. Returns a list of match strings (the full match followed by any groups) if successful, or #f if there is no match.\n" +
               "Example:\n" +
               "  (string-matches \"hello\" \"hel+o\") => (\"hello\")\n" +
               "  (string-matches \"abc123\" \"([a-z]+)([0-9]+)\") => (\"abc123\" \"abc\" \"123\")\n" +
               "  (string-matches \"hello\" \"xyz\") => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        var s = new String(Value.asString(arguments[0]));
        var pattern = Pattern.compile(new String(Value.asString(arguments[1])));
        var matcher = pattern.matcher(s);
        if (matcher.find()) {
            var groups = new Object[matcher.groupCount() + 1];
            for (var i = 0; i <= matcher.groupCount(); i++) {
                groups[i] = matcher.group(i).toCharArray();
            }
            return Pair.list(groups);
        }
        return Value.F;
    }
}
