namespace scheme;

public class PrimitiveSocketBinaryOutputPort : Primitive
{
    public override string Name() => "socket-binary-output-port";

    public override string Info() =>
        "Syntax: (socket-binary-output-port socket)\n" +
        "Library: (scm net sockets)\n" +
        "Description: Returns the binary output port for writing raw bytes to the socket.\n" +
        "Example:\n" +
        "  (write-u8 65 (socket-binary-output-port sock))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeSocket ss = (SchemeSocket) Value.AsNativeValue(arguments[0]).value;
        if (ss.binaryOutputPort == null)
            ss.binaryOutputPort = new BinaryOutputStream(ss.networkStream);
        return ss.binaryOutputPort;
    }
}
