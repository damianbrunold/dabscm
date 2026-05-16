namespace scheme;

public class PrimitiveStringLength : Primitive
{
    public override string Name()
    {
        return "string-length";
    }

    public override string Info()
    {
        return
            "Syntax: (string-length s)\n" +
            "Library: (scheme base) (srfi 13)\n" +
            "Description: Returns the number of characters in the string s.\n" +
            "Example:\n" +
            "  (string-length \"hello\") => 5\n" +
            "  (string-length \"\") => 0";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return (long) Value.AsString(arguments[0]).Length;
    }
}
