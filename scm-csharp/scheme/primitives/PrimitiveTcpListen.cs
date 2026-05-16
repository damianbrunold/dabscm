using System.Net;
using System.Net.Sockets;

namespace scheme;

public class PrimitiveTcpListen : Primitive
{
    public override string Name() => "tcp-listen";

    public override string Info() =>
        "Syntax: (tcp-listen port)\n" +
        "Library: (scm net sockets)\n" +
        "Description: Creates a TCP listener on the given port and starts listening for connections.\n" +
        "Example:\n" +
        "  (define l (tcp-listen 8080))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        int port = IntegerMath.ToInt(arguments[0]);
        var listener = new TcpListener(IPAddress.Any, port);
        listener.Start();
        return new NativeValue(new SchemeListener(listener));
    }
}
