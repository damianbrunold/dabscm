using System;
using System.Net.Sockets;
using System.Text;

namespace scheme;

public class PrimitiveWsSend : Primitive
{
    public override string Name() => "ws-send";

    public override string Info() =>
        "Syntax: (ws-send ws message)\n" +
        "Library: (scm net websocket)\n" +
        "Description: Sends a message over the WebSocket. message may be a string (text frame) " +
        "or a bytevector (binary frame).\n" +
        "Example:\n" +
        "  (ws-send ws \"Hello!\")";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        SchemeWebSocket ws = (SchemeWebSocket) Value.AsNativeValue(arguments[0]).value;
        byte[] payload;
        byte opcode;
        if (Value.IsString(arguments[1]))
        {
            payload = Encoding.UTF8.GetBytes(new String(Value.AsString(arguments[1])));
            opcode = 0x01; // text
        }
        else
        {
            payload = Value.AsBytevector(arguments[1]);
            opcode = 0x02; // binary
        }
        WsWriteFrame(ws.stream, opcode, payload, !ws.IsServer);
        return Value.T;
    }

    internal static void WsWriteFrame(NetworkStream stream, byte opcode, byte[] payload, bool mask)
    {
        int len = payload.Length;
        // FIN=1, opcode
        stream.WriteByte((byte)(0x80 | opcode));
        byte maskBit = mask ? (byte)0x80 : (byte)0x00;
        if (len < 126)
            stream.WriteByte((byte)(maskBit | len));
        else if (len < 65536)
        {
            stream.WriteByte((byte)(maskBit | 126));
            stream.WriteByte((byte)(len >> 8));
            stream.WriteByte((byte)(len & 0xFF));
        }
        else
        {
            stream.WriteByte((byte)(maskBit | 127));
            for (int i = 7; i >= 0; i--)
                stream.WriteByte((byte)((len >> (i * 8)) & 0xFF));
        }
        if (mask)
        {
            byte[] key = new byte[4];
            new Random().NextBytes(key);
            stream.Write(key, 0, 4);
            byte[] masked = new byte[len];
            for (int i = 0; i < len; i++)
                masked[i] = (byte)(payload[i] ^ key[i % 4]);
            stream.Write(masked, 0, len);
        }
        else
        {
            stream.Write(payload, 0, len);
        }
        stream.Flush();
    }
}
