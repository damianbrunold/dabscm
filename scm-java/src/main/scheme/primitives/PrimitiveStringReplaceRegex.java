package scheme.primitives;

import scheme.*;

import java.util.regex.*;
import java.util.concurrent.ConcurrentHashMap;

public class PrimitiveStringReplaceRegex extends Primitive {
    private static final ConcurrentHashMap<String, Pattern> cache = new ConcurrentHashMap<>();
    private static Pattern get(String pattern) {
        Pattern p = cache.get(pattern);
        if (p != null) return p;
        p = Pattern.compile(pattern);
        if (cache.size() > 256) cache.clear();
        cache.putIfAbsent(pattern, p);
        return p;
    }

    private static String expand(String template, Matcher m) {
        var sb = new StringBuilder();
        var i = 0;
        while (i < template.length()) {
            var c = template.charAt(i);
            if (c == '~' && i + 1 < template.length()) {
                var n = template.charAt(i + 1);
                if (n == '~') {
                    sb.append('~');
                    i += 2;
                } else if (Character.isDigit(n)) {
                    var j = i + 1;
                    while (j < template.length() && Character.isDigit(template.charAt(j))) j++;
                    var g = Integer.parseInt(template.substring(i + 1, j));
                    if (g <= m.groupCount()) {
                        var v = m.group(g);
                        if (v != null) sb.append(v);
                    }
                    i = j;
                } else {
                    sb.append(c);
                    i++;
                }
            } else {
                sb.append(c);
                i++;
            }
        }
        return sb.toString();
    }

    @Override
    public String name() {
        return "string-replace-all-regex";
    }

    @Override
    public String info() {
        return "Syntax: (string-replace-all-regex s pattern replacement)\n" +
               "Library: (scm string)\n" +
               "Description: Returns a new string with all matches of the regular expression pattern in s replaced by replacement. The replacement may refer to captured groups with ~0 (the whole match), ~1, ~2, ... (parenthesized groups). Use ~~ for a literal tilde. References to groups that did not participate in the match expand to the empty string.\n" +
               "Example:\n" +
               "  (string-replace-all-regex \"hello world\" \"o\" \"0\") => \"hell0 w0rld\"\n" +
               "  (string-replace-all-regex \"2024-01-31\" \"([0-9]+)-([0-9]+)-([0-9]+)\" \"~3.~2.~1\") => \"31.01.2024\"\n" +
               "  (string-replace-all-regex \"abc123def456\" \"[0-9]+\" \"#\") => \"abc#def#\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        var s = new String(Value.asString(arguments[0]));
        var pattern = get(new String(Value.asString(arguments[1])));
        var replace = new String(Value.asString(arguments[2]));
        var matcher = pattern.matcher(s);
        var result = new StringBuilder();
        var last = 0;
        while (matcher.find()) {
            result.append(s, last, matcher.start());
            result.append(expand(replace, matcher));
            last = matcher.end();
        }
        result.append(s.substring(last));
        return result.toString().toCharArray();
    }
}
