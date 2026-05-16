package scheme.primitives;
import scheme.*;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Random;

public class PrimitiveWsSend extends Primitive {
    @Override
    public String name() { return "ws-send"; }

    @Override
    public String info() {
        return "Syntax: (ws-send ws message)\n" +
               "Library: (scm net websocket)\n" +
               "Description: Sends a message over the WebSocket. message may be a string (text frame) or a bytevector (binary frame).\n" +
               "Example:\n" +
               "  (ws-send ws \"Hello!\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        SchemeWebSocket ws = (SchemeWebSocket) Value.asNativeValue(arguments[0]).value;
        byte[] payload;
        byte opcode;
        if (Value.isString(arguments[1])) {
            payload = new String(Value.asString(arguments[1])).getBytes(StandardCharsets.UTF_8);
            opcode = 0x01; // text
        } else {
            payload = Value.asBytevector(arguments[1]);
            opcode = 0x02; // binary
        }
        try {
            writeFrame(ws.output, opcode, payload, !ws.isServer);
        } catch (IOException e) { throw new SchemeError(pos, "ws-send: " + e.getMessage()); }
        return Value.T;
    }

    static void writeFrame(OutputStream out, byte opcode, byte[] payload, boolean mask) throws IOException {
        int len = payload.length;
        out.write(0x80 | opcode);
        int maskBit = mask ? 0x80 : 0x00;
        if (len < 126) {
            out.write(maskBit | len);
        } else if (len < 65536) {
            out.write(maskBit | 126);
            out.write(len >> 8);
            out.write(len & 0xFF);
        } else {
            out.write(maskBit | 127);
            for (int i = 7; i >= 0; i--) out.write((len >> (i * 8)) & 0xFF);
        }
        if (mask) {
            byte[] key = new byte[4];
            new Random().nextBytes(key);
            out.write(key);
            byte[] masked = new byte[len];
            for (int i = 0; i < len; i++) masked[i] = (byte)(payload[i] ^ key[i % 4]);
            out.write(masked);
        } else {
            out.write(payload);
        }
        out.flush();
    }
}
