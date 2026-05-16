using System.Net.Sockets;

namespace scheme;

public class PrimitiveTcpConnect : Primitive
{
    public override string Name() => "tcp-connect";

    public override string Info() =>
        "Syntax: (tcp-connect host port)\n" +
        "Library: (scm net sockets)\n" +
        "Description: Connects to a TCP server at the given host and port. Returns a socket.\n" +
        "Example:\n" +
        "  (define sock (tcp-connect \"localhost\" 8080))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        string host = new String(Value.AsString(arguments[0]));
        int port = IntegerMath.ToInt(arguments[1]);
        TcpClient client = new TcpClient(host, port);
        return new NativeValue(new SchemeSocket(client));
    }
}
