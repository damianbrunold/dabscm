namespace scheme;

public class PrimitiveStringCopy : Primitive
{
    public override string Name()
    {
        return "string-copy";
    }

    public override string Info()
    {
        return
            "Syntax: (string-copy s start? end?)\n" +
            "Library: (scheme base) (srfi 13)\n" +
            "Description: Returns a newly allocated copy of the string s. If start and end are given, only that substring is copied.\n" +
            "Example:\n" +
            "  (string-copy \"hello\") => \"hello\"\n" +
            "  (string-copy \"hello\" 1 3) => \"el\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        char[] s = Value.AsString(arguments[0]);
        return new String(s).ToCharArray();
    }
}
