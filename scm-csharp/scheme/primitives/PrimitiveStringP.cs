namespace scheme;

public class PrimitiveStringP : Primitive
{
    public override string Name()
    {
        return "string?";
    }

    public override string Info()
    {
        return
            "Syntax: (string? obj)\n" +
            "Library: (scheme base) (srfi 13)\n" +
            "Description: Returns #t if obj is a string, otherwise returns #f.\n" +
            "Example:\n" +
            "  (string? \"hello\") => #t\n" +
            "  (string? 42) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsString(arguments[0]);
    }
}
