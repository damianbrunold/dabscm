using System.Text;

namespace scheme;

public class PrimitiveUtf8ValidP : Primitive
{
    private static readonly UTF8Encoding Strict = new(false, true);

    public override string Name()
    {
        return "utf8-valid?";
    }

    public override string Info()
    {
        return
            "Syntax: (utf8-valid? bv [start [end]])\n" +
            "Library: (scm bytevector)\n" +
            "Description: Returns #t if the bytes of bv (or its range from start to\n" +
            "end) are well-formed UTF-8, #f otherwise. Use it to decide whether\n" +
            "utf8->string would replace any bytes with U+FFFD, for example to tell\n" +
            "UTF-8 files from Latin-1 ones.\n" +
            "Example:\n" +
            "  (utf8-valid? (bytevector #xC3 #xA4)) => #t\n" +
            "  (utf8-valid? (bytevector #xE4)) => #f";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        byte[] bv = Value.AsBytevector(arguments[0]);
        int start = arguments.Length > 1 ? IntegerMath.ToInt(arguments[1]) : 0;
        int end = arguments.Length > 2 ? IntegerMath.ToInt(arguments[2]) : bv.Length;
        if (start < 0 || end > bv.Length || start > end)
            throw new SchemeError(pos, "utf8-valid?: invalid range");
        try
        {
            Strict.GetCharCount(bv, start, end - start);
            return (object)true;
        }
        catch (DecoderFallbackException)
        {
            return (object)false;
        }
    }
}
