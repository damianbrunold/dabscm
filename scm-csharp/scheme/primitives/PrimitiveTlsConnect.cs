using System.Net.Sockets;
using System.Net.Security;

namespace scheme;

public class PrimitiveTlsConnect : Primitive
{
    public override string Name() => "tls-connect";

    public override string Info() =>
        "Syntax: (tls-connect host port)\n" +
        "Syntax: (tls-connect host port verify?)\n" +
        "Library: (scm net sockets)\n" +
        "Description: Connects to a TCP server at host:port and immediately performs a TLS\n" +
        "  handshake (implicit TLS, as used by SMTPS on port 465 or HTTPS). Returns a socket\n" +
        "  whose ports read and write encrypted data transparently. When verify? is omitted or\n" +
        "  true, the server certificate chain and host name are validated; passing #f disables\n" +
        "  validation (insecure, for testing only).\n" +
        "Example:\n" +
        "  (define sock (tls-connect \"smtp.example.com\" 465))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 3);
        string host = new string(Value.AsString(arguments[0]));
        int port = IntegerMath.ToInt(arguments[1]);
        bool verify = !(arguments.Length > 2 && arguments[2] is false);
        try
        {
            TcpClient client = new TcpClient(host, port);
            client.NoDelay = true;
            RemoteCertificateValidationCallback? cb =
                verify ? null : (s, c, ch, e) => true;
            SslStream ssl = new SslStream(client.GetStream(), false, cb);
            ssl.AuthenticateAsClient(host);
            return new NativeValue(new SchemeSocket(client, ssl));
        }
        catch (System.Exception e)
        {
            throw new SchemeError(pos, "tls-connect: " + e.Message);
        }
    }
}
