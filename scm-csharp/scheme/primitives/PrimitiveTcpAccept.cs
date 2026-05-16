using System.Net.Sockets;

namespace scheme;

public class PrimitiveTcpAccept : Primitive
{
    public override string Name() => "tcp-accept";

    public override string Info() =>
        "Syntax: (tcp-accept listener)\n" +
        "Library: (scm net sockets)\n" +
        "Description: Accepts an incoming TCP connection on the listener. Blocks until a connection arrives.\n" +
        "Example:\n" +
        "  (define sock (tcp-accept listener))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeListener sl = (SchemeListener) Value.AsNativeValue(arguments[0]).value;
        TcpClient client = sl.listener.AcceptTcpClient();
        return new NativeValue(new SchemeSocket(client));
    }
}
