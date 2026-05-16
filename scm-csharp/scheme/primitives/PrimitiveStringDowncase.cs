using System.Globalization;

namespace scheme;

public class PrimitiveStringDowncase : Primitive
{
    public override string Name() => "string-downcase";

    public override string Info() =>
        "Syntax: (string-downcase s)\n" +
        "Library: (scheme char)\n" +
        "Description: Returns a string that is the lowercase equivalent of s using full Unicode case mapping.\n" +
        "Example:\n" +
        "  (string-downcase \"HELLO\") => \"hello\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return UnicodeCaseMap.ToLower(new string(Value.AsString(arguments[0]))).ToCharArray();
    }
}
