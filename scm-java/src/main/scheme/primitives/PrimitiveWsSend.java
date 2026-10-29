package scheme.primitives;
import scheme.*;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

public class PrimitiveWsSend extends Primitive {
    @Override
    public String name() { return "ws-send"; }

    @Override
    public String info() {
        return "Syntax: (ws-send ws message)\n" +
               "Library: (scm net websocket)\n" +
               "Description: Sends a message over the WebSocket. message may be a string (text frame) or a bytevector\n" +
               "  (binary frame). Safe to call from several threads, also while another thread waits in ws-receive.\n" +
               "  Signals an error when the connection is closed.\n" +
               "Example:\n" +
               "  (ws-send ws \"Hello!\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        SchemeWebSocket ws = (SchemeWebSocket) Value.asNativeValue(arguments[0]).value;
        try {
            if (Value.isString(arguments[1]))
                ws.send(0x1, new String(Value.asString(arguments[1])).getBytes(StandardCharsets.UTF_8));
            else
                ws.send(0x2, Value.asBytevector(arguments[1]));
        } catch (IOException e) { throw new SchemeError(pos, "ws-send: " + e.getMessage()); }
        return Value.T;
    }
}
