using System.Text;

namespace scheme;

public class PrimitiveString : Primitive
{
    public override string Name()
    {
        return "string";
    }

    public override string Info()
    {
        return
            "Syntax: (string char ...)\n" +
            "Library: (scheme base) (srfi 13)\n" +
            "Description: Returns a newly allocated string composed of the given characters.\n" +
            "Example:\n" +
            "  (string #\\a #\\b #\\c) => \"abc\"\n" +
            "  (string) => \"\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        StringBuilder result = new StringBuilder();
        foreach (object argument in arguments)
        {
            result.Append(Value.AsChar(argument));
        }
        return result.ToString().ToCharArray();
    }
}
