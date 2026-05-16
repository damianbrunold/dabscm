using System.Globalization;

namespace scheme;

public class PrimitiveStringUpcase : Primitive
{
    public override string Name() => "string-upcase";

    public override string Info() =>
        "Syntax: (string-upcase s)\n" +
        "Library: (scheme char)\n" +
        "Description: Returns a string that is the uppercase equivalent of s using full Unicode case mapping.\n" +
        "Example:\n" +
        "  (string-upcase \"hello\") => \"HELLO\"\n" +
        "  (string-upcase \"ßa\") => \"SSA\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return UnicodeCaseMap.ToUpper(new string(Value.AsString(arguments[0]))).ToCharArray();
    }
}
