namespace scheme;

public class PrimitiveCharNumericP : Primitive
{
    public override string Name()
    {
        return "char-numeric?";
    }

    public override string Info()
    {
        return
            "Syntax: (char-numeric? char)\n" +
            "Library: (scheme char)\n" +
            "Description: Returns #t if char is a numeric character (digit).\n" +
            "Example:\n" +
            "  (char-numeric? #\\5) => #t\n" +
            "  (char-numeric? #\\a) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Char.IsDigit(Value.AsChar(arguments[0]));
    }
}
