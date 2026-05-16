namespace scheme;

public class PrimitiveSocketBinaryInputPort : Primitive
{
    public override string Name() => "socket-binary-input-port";

    public override string Info() =>
        "Syntax: (socket-binary-input-port socket)\n" +
        "Library: (scm net sockets)\n" +
        "Description: Returns the binary input port for reading raw bytes from the socket.\n" +
        "Example:\n" +
        "  (read-u8 (socket-binary-input-port sock))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeSocket ss = (SchemeSocket) Value.AsNativeValue(arguments[0]).value;
        if (ss.binaryInputPort == null)
            ss.binaryInputPort = new BinaryInputStream(ss.networkStream);
        return ss.binaryInputPort;
    }
}
