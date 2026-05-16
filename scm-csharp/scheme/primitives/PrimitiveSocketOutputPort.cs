namespace scheme;

public class PrimitiveSocketOutputPort : Primitive
{
    public override string Name() => "socket-output-port";

    public override string Info() =>
        "Syntax: (socket-output-port socket)\n" +
        "Library: (scm net sockets)\n" +
        "Description: Returns the textual output port for writing to the socket.\n" +
        "Example:\n" +
        "  (display \"hello\" (socket-output-port sock))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeSocket ss = (SchemeSocket) Value.AsNativeValue(arguments[0]).value;
        return ss.outputPort;
    }
}
