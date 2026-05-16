namespace scheme;

public class PrimitiveStringToSymbol : Primitive
{
    public override string Name()
    {
        return "string->symbol";
    }

    public override string Info()
    {
        return
            "Syntax: (string->symbol s)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the interned symbol whose name is the string s. Two calls with equal strings return the same symbol.\n" +
            "Example:\n" +
            "  (string->symbol \"hello\") => hello\n" +
            "  (eq? (string->symbol \"foo\") (string->symbol \"foo\")) => #t";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.Intern(new String(Value.AsString(arguments[0])));
    }
}
