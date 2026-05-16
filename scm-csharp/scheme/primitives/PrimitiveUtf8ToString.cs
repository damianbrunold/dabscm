using System.Text;

namespace scheme;

public class PrimitiveUtf8ToString : Primitive
{
    public override string Name() => "utf8->string";
    public override string Info()
    {
        return
            "Syntax: (utf8->string bv start? end?)\n" +
            "Library: (scheme base)\n" +
            "Description: Decodes the UTF-8 encoded bytes in bytevector bv (optionally from start to end) and returns the result as a string.\n" +
            "Example:\n" +
            "  (utf8->string #u8(104 101 108 108 111)) => \"hello\"\n" +
            "  (utf8->string #u8(104 101 108 108 111) 1 3) => \"el\"";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        byte[] bv = Value.AsBytevector(arguments[0]);
        int start = arguments.Length >= 2 ? IntegerMath.ToInt(arguments[1]) : 0;
        int end = arguments.Length >= 3 ? IntegerMath.ToInt(arguments[2]) : bv.Length;
        if (start < 0 || end > bv.Length || start > end)
            throw new SchemeError(pos, "utf8->string: invalid range");
        return Encoding.UTF8.GetString(bv, start, end - start).ToCharArray();
    }
}
