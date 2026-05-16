namespace scheme;

public class PrimitiveWsClose : Primitive
{
    public override string Name() => "ws-close";

    public override string Info() =>
        "Syntax: (ws-close ws)\n" +
        "Library: (scm net websocket)\n" +
        "Description: Sends a close frame and closes the WebSocket connection.\n" +
        "Example:\n" +
        "  (ws-close ws)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeWebSocket ws = (SchemeWebSocket) Value.AsNativeValue(arguments[0]).value;
        try
        {
            PrimitiveWsSend.WsWriteFrame(ws.stream, 0x08, new byte[0], !ws.IsServer);
            ws.stream.Close();
        }
        catch { }
        return Value.T;
    }
}
