namespace scheme;

public class PrimitiveWsP : Primitive
{
    public override string Name() => "ws?";

    public override string Info() =>
        "Syntax: (ws? x)\n" +
        "Library: (scm net websocket)\n" +
        "Description: Returns #t if x is a WebSocket object.\n" +
        "Example:\n" +
        "  (ws? ws) => #t";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsNativeValue(arguments[0]) && Value.AsNativeValue(arguments[0]).value is SchemeWebSocket
            ? Value.T : Value.F;
    }
}
