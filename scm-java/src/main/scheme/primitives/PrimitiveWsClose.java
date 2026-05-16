package scheme.primitives;
import scheme.*;

public class PrimitiveWsClose extends Primitive {
    @Override
    public String name() { return "ws-close"; }

    @Override
    public String info() {
        return "Syntax: (ws-close ws)\n" +
               "Library: (scm net websocket)\n" +
               "Description: Sends a close frame and closes the WebSocket connection.\n" +
               "Example:\n" +
               "  (ws-close ws)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeWebSocket ws = (SchemeWebSocket) Value.asNativeValue(arguments[0]).value;
        try {
            PrimitiveWsSend.writeFrame(ws.output, (byte)0x08, new byte[0], !ws.isServer);
            ws.output.close();
        } catch (Exception ignored) {}
        return Value.T;
    }
}
