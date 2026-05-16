namespace scheme;

public class PrimitiveReadU8 : Primitive
{
    private Modules modules;

    public PrimitiveReadU8(Modules modules) { this.modules = modules; }

    public override string Name() => "read-u8";
    public override string Info() =>
        "Syntax: (read-u8 port)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns the next byte available from the binary input port as an exact integer in the range 0 to 255. Returns an end-of-file object if no bytes are available.\n" +
        "Example:\n" +
        "  (let ((p (open-input-bytevector #u8(65 66))))\n" +
        "    (read-u8 p)) => 65";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 1);
        try
        {
            BinaryInputStream port = GetPort(pos, arguments);
            int b = port.ReadByte();
            return b == -1 ? (object)Value.EOF : (object)(long)(b & 0xFF);
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "read-u8: io failure: ~a", e.Message);
        }
    }

    private BinaryInputStream GetPort(SourcePos? pos, object[] arguments)
    {
        if (arguments.Length == 0)
            throw new SchemeError(pos, "read-u8: binary input port required");
        return Value.AsBinaryInputPort(arguments[0]);
    }
}
