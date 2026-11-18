package scheme.primitives;

import scheme.*;

public class PrimitiveStringWidth extends Primitive {
    @Override
    public String name() {
        return "string-width";
    }

    @Override
    public String info() {
        return "Syntax: (string-width s [start [end]])\n" +
               "Library: (scm terminal)\n" +
               "Description: Returns the number of terminal columns the string s (or\n" +
               "its substring from start to end) occupies, summing char-width over its\n" +
               "code points. Surrogate pairs count as one code point; control\n" +
               "characters count as 0.\n" +
               "Example:\n" +
               "  (string-width \"abc\") => 3\n" +
               "  (string-width \"\\x4E2D;\\x6587;\") => 4";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        char[] s = Value.asString(arguments[0]);
        int start = arguments.length > 1 ? IntegerMath.toInt(arguments[1]) : 0;
        int end = arguments.length > 2 ? IntegerMath.toInt(arguments[2]) : s.length;
        if (start < 0 || end > s.length || start > end)
            throw new SchemeError(pos, "string-width: invalid range");
        long total = 0;
        int i = start;
        while (i < end) {
            char c = s[i];
            int cp = c;
            if (Character.isHighSurrogate(c) && i + 1 < end && Character.isLowSurrogate(s[i + 1])) {
                cp = Character.toCodePoint(c, s[i + 1]);
                i += 2;
            } else {
                i++;
            }
            int w = CharWidth.width(cp);
            if (w > 0) total += w;
        }
        return total;
    }
}
