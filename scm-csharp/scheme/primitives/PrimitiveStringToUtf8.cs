using System.Text;

namespace scheme;

public class PrimitiveStringToUtf8 : Primitive
{
    public override string Name() => "string->utf8";
    public override string Info()
    {
        return
            "Syntax: (string->utf8 s start? end?)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns a bytevector containing the UTF-8 encoding of the string s. Optional start and end indices can be used to encode a substring.\n" +
            "Example:\n" +
            "  (string->utf8 \"abc\") => #u8(97 98 99)\n" +
            "  (string->utf8 \"hello\" 1 3) => #u8(101 108)";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        char[] s = Value.AsString(arguments[0]);
        int start = arguments.Length >= 2 ? IntegerMath.ToInt(arguments[1]) : 0;
        int end = arguments.Length >= 3 ? IntegerMath.ToInt(arguments[2]) : s.Length;
        if (start < 0 || end > s.Length || start > end)
            throw new SchemeError(pos, "string->utf8: invalid range");
        return Encoding.UTF8.GetBytes(s, start, end - start);
    }
}
