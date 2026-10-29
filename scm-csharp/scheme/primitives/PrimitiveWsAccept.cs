using System;
using System.Text;

namespace scheme;

public class PrimitiveWsAccept : Primitive
{
    public override string Name() => "ws-accept";

    public override string Info() =>
        "Syntax: (ws-accept socket)\n" +
        "Library: (scm net websocket)\n" +
        "Description: Performs a WebSocket server-side handshake (RFC 6455) on the given TCP socket. " +
        "Returns a WebSocket object.\n" +
        "  In an HTTP server, use http-websocket-upgrade instead.\n" +
        "Example:\n" +
        "  (define ws (ws-accept sock))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeSocket ss = (SchemeSocket) Value.AsNativeValue(arguments[0]).value;
        var stream = ss.client.GetStream();
        string? headers = SchemeWebSocket.ReadHeaders(stream);
        string? wsKey = null;
        if (headers != null)
        {
            foreach (var line in headers.Split("\r\n"))
            {
                if (line.StartsWith("Sec-WebSocket-Key:", StringComparison.OrdinalIgnoreCase))
                    wsKey = line.Substring(line.IndexOf(':') + 1).Trim();
            }
        }
        if (wsKey == null)
            throw new SchemeError(pos, "ws-accept: missing Sec-WebSocket-Key header");

        string response =
            "HTTP/1.1 101 Switching Protocols\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            $"Sec-WebSocket-Accept: {SchemeWebSocket.AcceptKey(wsKey)}\r\n\r\n";
        byte[] responseBytes = Encoding.UTF8.GetBytes(response);
        stream.Write(responseBytes, 0, responseBytes.Length);
        stream.Flush();

        return new NativeValue(new SchemeWebSocket(stream, true, ss.client));
    }
}
