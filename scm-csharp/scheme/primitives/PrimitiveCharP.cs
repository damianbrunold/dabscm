namespace scheme;

public class PrimitiveCharP : Primitive
{
    public override string Name()
    {
        return "char?";
    }

    public override string Info()
    {
        return
            "Syntax: (char? obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is a character, otherwise returns #f.\n" +
            "Example:\n" +
            "  (char? #\\a) => #t\n" +
            "  (char? \"a\") => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsChar(arguments[0]);
    }
}
