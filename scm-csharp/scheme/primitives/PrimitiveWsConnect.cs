using System;
using System.IO;
using System.Net.Sockets;
using System.Text;

namespace scheme;

public class PrimitiveWsConnect : Primitive
{
    public override string Name() => "ws-connect";

    public override string Info() =>
        "Syntax: (ws-connect host port path)\n" +
        "Library: (scm net websocket)\n" +
        "Description: Connects to a WebSocket server (RFC 6455 client handshake). Returns a WebSocket object.\n" +
        "Example:\n" +
        "  (define ws (ws-connect \"localhost\" 8080 \"/ws\"))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        string host = new String(Value.AsString(arguments[0]));
        int port = IntegerMath.ToInt(arguments[1]);
        string path = new String(Value.AsString(arguments[2]));

        var client = new TcpClient(host, port);
        var stream = client.GetStream();
        string key = Convert.ToBase64String(Guid.NewGuid().ToByteArray());

        string request =
            $"GET {path} HTTP/1.1\r\n" +
            $"Host: {host}:{port}\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            $"Sec-WebSocket-Key: {key}\r\n" +
            "Sec-WebSocket-Version: 13\r\n\r\n";
        byte[] requestBytes = Encoding.UTF8.GetBytes(request);
        stream.Write(requestBytes, 0, requestBytes.Length);
        stream.Flush();

        // Read response (just drain headers)
        var reader = new StreamReader(stream, Encoding.UTF8, leaveOpen: true);
        while ((reader.ReadLine() ?? "") != "") { }

        return new NativeValue(new SchemeWebSocket(stream, false));
    }
}
