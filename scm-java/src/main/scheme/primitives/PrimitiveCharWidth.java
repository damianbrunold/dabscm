package scheme.primitives;

import scheme.*;

public class PrimitiveCharWidth extends Primitive {
    @Override
    public String name() {
        return "char-width";
    }

    @Override
    public String info() {
        return "Syntax: (char-width c)\n" +
               "Library: (scm terminal)\n" +
               "Description: Returns the number of terminal columns the character or\n" +
               "code point c occupies: 2 for East Asian wide and fullwidth characters\n" +
               "and wide emoji, 0 for combining marks, format characters and other\n" +
               "zero-width characters, -1 for C0 and C1 control characters, and 1\n" +
               "otherwise. c may be a char or an integer code point (needed above\n" +
               "#xFFFF, which a single char cannot hold); a lone surrogate counts as 1.\n" +
               "Example:\n" +
               "  (char-width #\\a) => 1\n" +
               "  (char-width (integer->char #x4E2D)) => 2\n" +
               "  (char-width #x1F600) => 2\n" +
               "  (char-width (integer->char #x301)) => 0";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        Object a = arguments[0];
        int cp = a instanceof Character ? (Character) a : IntegerMath.toInt(a);
        if (cp < 0 || cp > 0x10FFFF)
            throw new SchemeError(pos, "char-width: ~a is not a code point", (long) cp);
        return (long) CharWidth.width(cp);
    }
}
