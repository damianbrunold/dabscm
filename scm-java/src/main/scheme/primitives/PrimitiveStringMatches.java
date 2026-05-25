
package scheme.primitives;

import scheme.*;

import java.util.regex.*;
import java.util.concurrent.ConcurrentHashMap;

public class PrimitiveStringMatches extends Primitive {
    private static final ConcurrentHashMap<String, Pattern> cache = new ConcurrentHashMap<>();
    private static Pattern get(String pattern) {
        Pattern p = cache.get(pattern);
        if (p != null) return p;
        p = Pattern.compile(pattern);
        if (cache.size() > 256) cache.clear();
        cache.putIfAbsent(pattern, p);
        return p;
    }

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
        var pattern = get(new String(Value.asString(arguments[1])));
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
