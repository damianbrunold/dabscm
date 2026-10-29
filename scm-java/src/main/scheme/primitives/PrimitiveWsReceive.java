package scheme.primitives;
import scheme.*;

public class PrimitiveWsReceive extends Primitive {
    @Override
    public String name() { return "ws-receive"; }

    @Override
    public String info() {
        return "Syntax: (ws-receive ws [timeout-ms])\n" +
               "Library: (scm net websocket)\n" +
               "Description: Waits for the next message from the WebSocket and returns it: a string for a text\n" +
               "  message, a bytevector for a binary one (fragmented messages are joined), or #f when the\n" +
               "  connection has closed (by the peer, an error, or a message over 16 MB). Pings are answered\n" +
               "  with pongs on the way. With timeout-ms, returns the symbol timeout if no message began\n" +
               "  within that time (the connection stays usable).\n" +
               "Example:\n" +
               "  (ws-receive ws) => \"Hello!\"\n" +
               "  (ws-receive ws 30000) => timeout";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        SchemeWebSocket ws = (SchemeWebSocket) Value.asNativeValue(arguments[0]).value;
        int timeout = arguments.length > 1 ? IntegerMath.toInt(arguments[1]) : 0;
        return ws.receive(timeout);
    }
}
