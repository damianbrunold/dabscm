namespace scheme;

public class PrimitivePeekU8 : Primitive
{
    public override string Name() => "peek-u8";
    public override string Info() =>
        "Syntax: (peek-u8 port)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns the next byte available from the binary input port without consuming it. Returns an end-of-file object if no bytes are available.\n" +
        "Example:\n" +
        "  (let ((p (open-input-bytevector #u8(10 20))))\n" +
        "    (peek-u8 p)) => 10";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        try
        {
            BinaryInputStream port = Value.AsBinaryInputPort(arguments[0]);
            int b = port.PeekByte();
            return b == -1 ? (object)Value.EOF : (object)(long)(b & 0xFF);
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "peek-u8: io failure: ~a", e.Message);
        }
    }
}
