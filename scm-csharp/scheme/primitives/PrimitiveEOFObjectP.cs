namespace scheme;

public class PrimitiveEOFObjectP : Primitive
{
    public override string Name()
    {
        return "eof-object?";
    }

    public override string Info()
    {
        return
            "Syntax: (eof-object? obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is an end-of-file object, otherwise returns #f.\n" +
            "Example:\n" +
            "  (eof-object? (read (open-input-string \"\"))) => #t";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsEOFObject(arguments[0]);
    }
}
