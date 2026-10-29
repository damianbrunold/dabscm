using System;
using System.Text;

namespace scheme;

public class PrimitiveWsSend : Primitive
{
    public override string Name() => "ws-send";

    public override string Info() =>
        "Syntax: (ws-send ws message)\n" +
        "Library: (scm net websocket)\n" +
        "Description: Sends a message over the WebSocket. message may be a string (text frame) or a bytevector\n" +
        "  (binary frame). Safe to call from several threads, also while another thread waits in ws-receive.\n" +
        "  Signals an error when the connection is closed.\n" +
        "Example:\n" +
        "  (ws-send ws \"Hello!\")";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        SchemeWebSocket ws = (SchemeWebSocket) Value.AsNativeValue(arguments[0]).value;
        try
        {
            if (Value.IsString(arguments[1]))
                ws.Send(0x1, Encoding.UTF8.GetBytes(new string(Value.AsString(arguments[1]))));
            else
                ws.Send(0x2, Value.AsBytevector(arguments[1]));
        }
        catch (Exception e) when (e is IOException || e is ObjectDisposedException)
        {
            throw new SchemeError(pos, "ws-send: " + e.Message);
        }
        return Value.T;
    }
}
