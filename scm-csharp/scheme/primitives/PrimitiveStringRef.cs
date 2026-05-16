namespace scheme;

public class PrimitiveStringRef : Primitive
{
    public override string Name()
    {
        return "string-ref";
    }

    public override string Info()
    {
        return
            "Syntax: (string-ref s k)\n" +
            "Library: (scheme base) (srfi 13)\n" +
            "Description: Returns the character at index k in the string s. It is an error if k is out of range.\n" +
            "Example:\n" +
            "  (string-ref \"hello\" 0) => #\\h\n" +
            "  (string-ref \"hello\" 4) => #\\o";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        return Value.AsString(arguments[0])[(int) (long) arguments[1]];
    }
}
