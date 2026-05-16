package scheme.primitives;
import scheme.*;

public class PrimitiveWsP extends Primitive {
    @Override
    public String name() { return "ws?"; }

    @Override
    public String info() {
        return "Syntax: (ws? x)\n" +
               "Library: (scm net websocket)\n" +
               "Description: Returns #t if x is a WebSocket object.\n" +
               "Example:\n" +
               "  (ws? ws) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isNativeValue(arguments[0]) && Value.asNativeValue(arguments[0]).value instanceof SchemeWebSocket
            ? Value.T : Value.F;
    }
}
