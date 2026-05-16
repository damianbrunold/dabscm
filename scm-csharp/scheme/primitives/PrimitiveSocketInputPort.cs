namespace scheme;

public class PrimitiveSocketInputPort : Primitive
{
    public override string Name() => "socket-input-port";

    public override string Info() =>
        "Syntax: (socket-input-port socket)\n" +
        "Library: (scm net sockets)\n" +
        "Description: Returns the textual input port for reading from the socket.\n" +
        "Example:\n" +
        "  (read-line (socket-input-port sock))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeSocket ss = (SchemeSocket) Value.AsNativeValue(arguments[0]).value;
        return ss.inputPort;
    }
}
