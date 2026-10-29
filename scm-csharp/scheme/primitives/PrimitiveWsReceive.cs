namespace scheme;

public class PrimitiveWsReceive : Primitive
{
    public override string Name() => "ws-receive";

    public override string Info() =>
        "Syntax: (ws-receive ws [timeout-ms])\n" +
        "Library: (scm net websocket)\n" +
        "Description: Waits for the next message from the WebSocket and returns it: a string for a text\n" +
        "  message, a bytevector for a binary one (fragmented messages are joined), or #f when the\n" +
        "  connection has closed (by the peer, an error, or a message over 16 MB). Pings are answered\n" +
        "  with pongs on the way. With timeout-ms, returns the symbol timeout if no message began\n" +
        "  within that time (the connection stays usable).\n" +
        "Example:\n" +
        "  (ws-receive ws) => \"Hello!\"\n" +
        "  (ws-receive ws 30000) => timeout";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        SchemeWebSocket ws = (SchemeWebSocket) Value.AsNativeValue(arguments[0]).value;
        int timeout = arguments.Length > 1 ? IntegerMath.ToInt(arguments[1]) : 0;
        return ws.Receive(timeout);
    }
}
