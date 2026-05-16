using System;
using System.Text;

namespace scheme;

public class PrimitiveWsReceive : Primitive
{
    public override string Name() => "ws-receive";

    public override string Info() =>
        "Syntax: (ws-receive ws)\n" +
        "Library: (scm net websocket)\n" +
        "Description: Receives a message from the WebSocket. Returns a string for text frames, " +
        "a bytevector for binary frames, or #f on close/error.\n" +
        "Example:\n" +
        "  (ws-receive ws) => \"Hello!\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeWebSocket ws = (SchemeWebSocket) Value.AsNativeValue(arguments[0]).value;
        try
        {
            var stream = ws.stream;
            int b0 = stream.ReadByte();
            if (b0 < 0) return Value.F;
            int b1 = stream.ReadByte();
            if (b1 < 0) return Value.F;
            byte opcode = (byte)(b0 & 0x0F);
            bool masked = (b1 & 0x80) != 0;
            long payloadLen = b1 & 0x7F;
            if (payloadLen == 126)
            {
                payloadLen = (stream.ReadByte() << 8) | stream.ReadByte();
            }
            else if (payloadLen == 127)
            {
                payloadLen = 0;
                for (int i = 0; i < 8; i++)
                    payloadLen = (payloadLen << 8) | (byte)stream.ReadByte();
            }
            byte[] maskKey = new byte[4];
            if (masked)
            {
                for (int i = 0; i < 4; i++) maskKey[i] = (byte)stream.ReadByte();
            }
            byte[] payload = new byte[payloadLen];
            int totalRead = 0;
            while (totalRead < payloadLen)
            {
                int r = stream.Read(payload, totalRead, (int)(payloadLen - totalRead));
                if (r <= 0) break;
                totalRead += r;
            }
            if (masked)
                for (int i = 0; i < totalRead; i++)
                    payload[i] ^= maskKey[i % 4];
            if (opcode == 0x08) return Value.F; // close
            if (opcode == 0x01) return Encoding.UTF8.GetString(payload, 0, totalRead).ToCharArray(); // text
            return payload; // binary: return as bytevector (byte[])
        }
        catch
        {
            return Value.F;
        }
    }
}
