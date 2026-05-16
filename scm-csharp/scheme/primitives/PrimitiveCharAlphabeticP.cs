namespace scheme;

public class PrimitiveCharAlphabeticP : Primitive
{
    public override string Name()
    {
        return "char-alphabetic?";
    }

    public override string Info()
    {
        return
            "Syntax: (char-alphabetic? char)\n" +
            "Library: (scheme char)\n" +
            "Description: Returns #t if char is an alphabetic character.\n" +
            "Example:\n" +
            "  (char-alphabetic? #\\a) => #t\n" +
            "  (char-alphabetic? #\\1) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Char.IsLetter(Value.AsChar(arguments[0]));
    }
}
