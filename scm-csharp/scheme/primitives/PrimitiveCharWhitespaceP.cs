namespace scheme;

public class PrimitiveCharWhitespaceP : Primitive
{
    public override string Name()
    {
        return "char-whitespace?";
    }

    public override string Info()
    {
        return
            "Syntax: (char-whitespace? char)\n" +
            "Library: (scheme char)\n" +
            "Description: Returns #t if char is a whitespace character (space, tab, newline, etc.).\n" +
            "Example:\n" +
            "  (char-whitespace? #\\space) => #t\n" +
            "  (char-whitespace? #\\a) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Char.IsWhiteSpace(Value.AsChar(arguments[0]));
    }
}
