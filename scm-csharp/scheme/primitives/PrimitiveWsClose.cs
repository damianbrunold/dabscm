namespace scheme;

public class PrimitiveWsClose : Primitive
{
    public override string Name() => "ws-close";

    public override string Info() =>
        "Syntax: (ws-close ws)\n" +
        "Library: (scm net websocket)\n" +
        "Description: Sends a close frame (status 1000) and closes the WebSocket connection; a thread\n" +
        "  waiting in ws-receive gets #f.\n" +
        "Example:\n" +
        "  (ws-close ws)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeWebSocket ws = (SchemeWebSocket) Value.AsNativeValue(arguments[0]).value;
        ws.Close(1000);
        ws.Shutdown();
        return Value.T;
    }
}
