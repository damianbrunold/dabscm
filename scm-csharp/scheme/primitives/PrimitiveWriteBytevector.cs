namespace scheme;

public class PrimitiveWriteBytevector : Primitive
{
    public override string Name() => "write-bytevector";
    public override string Info()
    {
        return
            "Syntax: (write-bytevector bv port? start? end?)\n" +
            "Library: (scheme base)\n" +
            "Description: Writes the bytes of bytevector bv to binary output port, optionally restricted to the range [start, end).\n" +
            "Example:\n" +
            "  (write-bytevector #u8(1 2 3) port)\n" +
            "  (write-bytevector #u8(1 2 3 4 5) port 1 3)";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 4);
        try
        {
            byte[] bv = Value.AsBytevector(arguments[0]);
            BinaryOutputStream port = Value.AsBinaryOutputPort(arguments[1]);
            int start = arguments.Length >= 3 ? IntegerMath.ToInt(arguments[2]) : 0;
            int end = arguments.Length >= 4 ? IntegerMath.ToInt(arguments[3]) : bv.Length;
            for (int i = start; i < end; i++)
                port.WriteByte(bv[i]);
            return new Values();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "write-bytevector: io failure: ~a", e.Message);
        }
    }
}
