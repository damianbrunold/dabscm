package scheme.primitives;

import scheme.Primitive;
import scheme.Value;
import scheme.SourcePos;

public class PrimitiveCharWhitespaceP extends Primitive {
    @Override
    public String name() {
        return "char-whitespace?";
    }

    @Override
    public String info() {
        return "Syntax: (char-whitespace? char)\n" +
               "Library: (scheme char)\n" +
               "Description: Returns #t if char is a whitespace character (space, tab, newline, etc.).\n" +
               "Example:\n" +
               "  (char-whitespace? #\\space) => #t\n" +
               "  (char-whitespace? #\\a) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return isWhitespace(Value.asChar(arguments[0]));
    }

    // The Unicode White_Space property
    public static boolean isWhitespace(char c) {
        if (c <= ' ') return c == ' ' || (c >= '\t' && c <= '\r');
        if (c < 0x85) return false;
        return c == 0x85 || c == 0xA0 || c == 0x1680 || (c >= 0x2000 && c <= 0x200A)
            || c == 0x2028 || c == 0x2029 || c == 0x202F || c == 0x205F || c == 0x3000;
    }
}
