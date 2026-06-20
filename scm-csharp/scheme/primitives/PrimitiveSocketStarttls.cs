using System.IO;
using System.Net.Security;

namespace scheme;

public class PrimitiveSocketStarttls : Primitive
{
    public override string Name() => "socket-starttls!";

    public override string Info() =>
        "Syntax: (socket-starttls! socket host)\n" +
        "Syntax: (socket-starttls! socket host verify?)\n" +
        "Library: (scm net sockets)\n" +
        "Description: Upgrades an already-connected plaintext socket to TLS in place (the\n" +
        "  STARTTLS mechanism of SMTP/IMAP/etc.). Wraps the socket's raw underlying stream in\n" +
        "  a TLS stream and rebuilds the socket's input and output ports over it, so subsequent\n" +
        "  socket-input-port / socket-output-port use the encrypted channel. host is the server\n" +
        "  name used for certificate validation. When verify? is omitted or true, the server\n" +
        "  certificate chain and host name are validated; #f disables validation (insecure).\n" +
        "  Returns the socket. The pre-upgrade dialogue must be read with socket-read-line so\n" +
        "  no plaintext past the upgrade boundary is buffered. Returns the socket.\n" +
        "Example:\n" +
        "  (socket-starttls! sock \"smtp.example.com\")";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 3);
        SchemeSocket ss = (SchemeSocket) Value.AsNativeValue(arguments[0]).value;
        string host = new string(Value.AsString(arguments[1]));
        bool verify = !(arguments.Length > 2 && arguments[2] is false);
        try
        {
            RemoteCertificateValidationCallback? cb =
                verify ? null : (s, c, ch, e) => true;
            SslStream ssl = new SslStream(ss.networkStream, false, cb);
            ssl.AuthenticateAsClient(host);
            ss.networkStream = ssl;
            ss.inputPort = new TextStream(new StreamReader(ssl), "{socket}");
            ss.outputPort = new TextOutputStream(new StreamWriter(ssl) { AutoFlush = false });
            ss.binaryInputPort = null;
            ss.binaryOutputPort = null;
            return arguments[0];
        }
        catch (System.Exception e)
        {
            throw new SchemeError(pos, "socket-starttls!: " + e.Message);
        }
    }
}
