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
        return Character.isWhitespace(Value.asChar(arguments[0]));
    }
}
