package scheme.primitives;
import scheme.*;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

public class PrimitiveWsReceive extends Primitive {
    @Override
    public String name() { return "ws-receive"; }

    @Override
    public String info() {
        return "Syntax: (ws-receive ws)\n" +
               "Library: (scm net websocket)\n" +
               "Description: Receives a message from the WebSocket. Returns a string for text frames, " +
               "a bytevector for binary frames, or #f on close/error.\n" +
               "Example:\n" +
               "  (ws-receive ws) => \"Hello!\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeWebSocket ws = (SchemeWebSocket) Value.asNativeValue(arguments[0]).value;
        try {
            InputStream in = ws.input;
            int b0 = in.read(); if (b0 < 0) return Value.F;
            int b1 = in.read(); if (b1 < 0) return Value.F;
            byte opcode = (byte)(b0 & 0x0F);
            boolean masked = (b1 & 0x80) != 0;
            long payloadLen = b1 & 0x7F;
            if (payloadLen == 126) {
                payloadLen = ((in.read() & 0xFF) << 8) | (in.read() & 0xFF);
            } else if (payloadLen == 127) {
                payloadLen = 0;
                for (int i = 0; i < 8; i++) payloadLen = (payloadLen << 8) | (in.read() & 0xFF);
            }
            byte[] maskKey = new byte[4];
            if (masked) { for (int i = 0; i < 4; i++) maskKey[i] = (byte) in.read(); }
            byte[] payload = new byte[(int)payloadLen];
            int totalRead = 0;
            while (totalRead < payloadLen) {
                int r = in.read(payload, totalRead, (int)(payloadLen - totalRead));
                if (r <= 0) break;
                totalRead += r;
            }
            if (masked) for (int i = 0; i < totalRead; i++) payload[i] ^= maskKey[i % 4];
            if (opcode == 0x08) return Value.F; // close
            if (opcode == 0x01) return new String(payload, 0, totalRead, StandardCharsets.UTF_8).toCharArray();
            return payload; // binary
        } catch (Exception e) { return Value.F; }
    }
}
