namespace scheme;

public class PrimitiveCharUpperCaseP : Primitive
{
    public override string Name()
    {
        return "char-upper-case?";
    }

    public override string Info()
    {
        return
            "Syntax: (char-upper-case? char)\n" +
            "Library: (scheme char)\n" +
            "Description: Returns #t if char is an uppercase character.\n" +
            "Example:\n" +
            "  (char-upper-case? #\\A) => #t\n" +
            "  (char-upper-case? #\\a) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Char.IsUpper(Value.AsChar(arguments[0]));
    }
}
