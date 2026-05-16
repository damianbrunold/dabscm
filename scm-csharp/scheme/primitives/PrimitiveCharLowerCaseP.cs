namespace scheme;

public class PrimitiveCharLowerCaseP : Primitive
{
    public override string Name()
    {
        return "char-lower-case?";
    }

    public override string Info()
    {
        return
            "Syntax: (char-lower-case? char)\n" +
            "Library: (scheme char)\n" +
            "Description: Returns #t if char is a lowercase character.\n" +
            "Example:\n" +
            "  (char-lower-case? #\\a) => #t\n" +
            "  (char-lower-case? #\\A) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Char.IsLower(Value.AsChar(arguments[0]));
    }
}
