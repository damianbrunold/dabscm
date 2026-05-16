using System;
using System.IO;
using System.Net.Sockets;
using System.Security.Cryptography;
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
        "Example:\n" +
        "  (define ws (ws-accept sock))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeSocket ss = (SchemeSocket) Value.AsNativeValue(arguments[0]).value;
        var stream = ss.client.GetStream();
        var reader = new StreamReader(stream, Encoding.UTF8, leaveOpen: true);

        // Read HTTP upgrade request
        string? wsKey = null;
        string? line;
        while ((line = reader.ReadLine()) != null && line.Length > 0)
        {
            if (line.StartsWith("Sec-WebSocket-Key:", StringComparison.OrdinalIgnoreCase))
                wsKey = line.Substring(line.IndexOf(':') + 1).Trim();
        }
        if (wsKey == null)
            throw new SchemeError(pos, "ws-accept: missing Sec-WebSocket-Key header");

        string accept = Convert.ToBase64String(
            SHA1.HashData(Encoding.UTF8.GetBytes(wsKey + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")));

        string response =
            "HTTP/1.1 101 Switching Protocols\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            $"Sec-WebSocket-Accept: {accept}\r\n\r\n";
        byte[] responseBytes = Encoding.UTF8.GetBytes(response);
        stream.Write(responseBytes, 0, responseBytes.Length);
        stream.Flush();

        return new NativeValue(new SchemeWebSocket(stream, true));
    }
}
