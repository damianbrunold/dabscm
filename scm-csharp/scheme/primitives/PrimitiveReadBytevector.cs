namespace scheme;

public class PrimitiveReadBytevector : Primitive
{
    public override string Name() => "read-bytevector";
    public override string Info() =>
        "Syntax: (read-bytevector k port)\n" +
        "Library: (scheme base)\n" +
        "Description: Reads up to k bytes from the binary input port and returns them as a freshly allocated bytevector. Returns an end-of-file object if no bytes are available.\n" +
        "Example:\n" +
        "  (let ((p (open-input-bytevector #u8(1 2 3))))\n" +
        "    (read-bytevector 2 p)) => #u8(1 2)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        try
        {
            int k = IntegerMath.ToInt(arguments[0]);
            BinaryInputStream port = Value.AsBinaryInputPort(arguments[1]);
            if (k == 0) return new byte[0];
            byte[] buf = new byte[k];
            int read = port.Read(buf, 0, k);
            if (read == 0) return Value.EOF;
            if (read < k)
            {
                byte[] shorter = new byte[read];
                Array.Copy(buf, shorter, read);
                return shorter;
            }
            return buf;
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "read-bytevector: io failure: ~a", e.Message);
        }
    }
}
