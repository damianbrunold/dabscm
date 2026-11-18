namespace scheme;

public class PrimitiveCharWidth : Primitive
{
    public override string Name()
    {
        return "char-width";
    }

    public override string Info()
    {
        return
            "Syntax: (char-width c)\n" +
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

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        object a = arguments[0];
        int cp = a is char c ? c : IntegerMath.ToInt(a);
        if (cp < 0 || cp > 0x10FFFF)
            throw new SchemeError(pos, "char-width: ~a is not a code point", (long) cp);
        return (long) CharWidth.Width(cp);
    }
}
