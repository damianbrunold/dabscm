namespace scheme;

public class PrimitiveWriteU8 : Primitive
{
    public override string Name() => "write-u8";
    public override string Info()
    {
        return
            "Syntax: (write-u8 byte port?)\n" +
            "Library: (scheme base)\n" +
            "Description: Writes a single byte (an exact integer in the range 0-255) to the given binary output port.\n" +
            "Example:\n" +
            "  (write-u8 65 port)\n" +
            "  (write-u8 0 port)";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        try
        {
            long b = IntegerMath.ToLong(arguments[0]);
            if (b < 0 || b > 255) throw new SchemeError(pos, "write-u8: byte out of range: ~s", b);
            Value.AsBinaryOutputPort(arguments[1]).WriteByte((byte)b);
            return new Values();
        }
        catch (SchemeError) { throw; }
        catch (Exception e)
        {
            throw new SchemeError(pos, "write-u8: io failure: ~a", e.Message);
        }
    }
}
