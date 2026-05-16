using System.Text;

namespace scheme;

public class PrimitiveStringAppend : Primitive
{
    public override string Name()
    {
        return "string-append";
    }

    public override string Info()
    {
        return
            "Syntax: (string-append string ...)\n" +
            "Library: (scheme base) (srfi 13)\n" +
            "Description: Returns a newly allocated string whose characters are the concatenation of the characters in the given strings.\n" +
            "Example:\n" +
            "  (string-append \"foo\" \"bar\") => \"foobar\"\n" +
            "  (string-append \"a\" \"b\" \"c\") => \"abc\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        StringBuilder result = new StringBuilder();
        foreach (object argument in arguments)
        {
            result.Append(Value.AsString(argument));
        }
        return result.ToString().ToCharArray();
    }
}
