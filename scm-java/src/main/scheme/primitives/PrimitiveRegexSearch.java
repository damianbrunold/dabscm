package scheme.primitives;

import scheme.*;

import java.util.regex.*;

public class PrimitiveRegexSearch extends Primitive {
    @Override
    public String name() {
        return "regex-search";
    }

    @Override
    public String info() {
        return "Syntax: (regex-search s pattern [start])\n" +
               "Library: (scm string)\n" +
               "Description: Searches s for the first match of the regular expression\n" +
               "pattern at or after index start (default 0). Returns a vector with one\n" +
               "entry per group, the whole match first: each entry is a pair\n" +
               "(start . end) of string indexes, or #f for a group that does not take\n" +
               "part in the match. Returns #f if there is no match. Lookbehind, \\b and\n" +
               "^ see the characters before start, so ^ only matches at index 0 unless\n" +
               "the pattern enables multi-line mode with (?m). The pattern syntax is\n" +
               "that of the host regex engine (java.util.regex or .NET Regex); the\n" +
               "common subset (classes, quantifiers, groups, (?i), (?m), lookaround)\n" +
               "behaves the same in both.\n" +
               "Example:\n" +
               "  (regex-search \"abc123\" \"([a-z]+)([0-9]+)\") => #((0 . 6) (0 . 3) (3 . 6))\n" +
               "  (regex-search \"ab ab\" \"ab\" 1) => #((3 . 5))\n" +
               "  (regex-search \"b\" \"(x)?b\") => #((0 . 1) #f)\n" +
               "  (regex-search \"hello\" \"xyz\") => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 3);
        String s = new String(Value.asString(arguments[0]));
        Pattern pattern;
        try {
            pattern = PrimitiveStringMatchesCache.get(new String(Value.asString(arguments[1])));
        } catch (PatternSyntaxException e) {
            throw new SchemeError(pos, "regex-search: invalid pattern: ~a", e.getDescription());
        }
        int start = arguments.length > 2 ? IntegerMath.toInt(arguments[2]) : 0;
        if (start < 0 || start > s.length())
            throw new SchemeError(pos, "regex-search: start ~a out of range", (long) start);
        Matcher m = pattern.matcher(s);
        m.useTransparentBounds(true);
        m.useAnchoringBounds(false);
        m.region(start, s.length());
        if (!m.find()) return Value.F;
        Object[] result = new Object[m.groupCount() + 1];
        for (int i = 0; i <= m.groupCount(); i++) {
            int gs = m.start(i);
            result[i] = gs < 0 ? Value.F : new Pair((long) gs, (long) m.end(i));
        }
        return result;
    }
}
