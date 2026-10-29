package scheme.primitives;
import scheme.*;

public class PrimitiveWsClose extends Primitive {
    @Override
    public String name() { return "ws-close"; }

    @Override
    public String info() {
        return "Syntax: (ws-close ws)\n" +
               "Library: (scm net websocket)\n" +
               "Description: Sends a close frame (status 1000) and closes the WebSocket connection; a thread\n" +
               "  waiting in ws-receive gets #f.\n" +
               "Example:\n" +
               "  (ws-close ws)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeWebSocket ws = (SchemeWebSocket) Value.asNativeValue(arguments[0]).value;
        ws.close(1000);
        ws.shutdown();
        return Value.T;
    }
}
