namespace scheme;

public class PrimitiveHttpWebsocketUpgrade : Primitive
{
    public override string Name() => "http-websocket-upgrade";

    public override string Info() =>
        "Syntax: (http-websocket-upgrade handler [headers])\n" +
        "Library: (scm net http response)\n" +
        "Description: The response that turns the request's connection into a WebSocket (RFC 6455):\n" +
        "  tcp-http-serve checks the upgrade request (else it answers 400, or 426 for another protocol\n" +
        "  version), sends 101 Switching Protocols with headers (an alist, e.g. a chosen\n" +
        "  Sec-WebSocket-Protocol), and calls (handler ws) on the server thread; use ws-receive,\n" +
        "  ws-send and ws-close from (scm net websocket). The connection closes when handler returns,\n" +
        "  and holds one of the server's max-threads until then.\n" +
        "Example:\n" +
        "  (route-get \"/echo\" (lambda (req)\n" +
        "    (http-websocket-upgrade\n" +
        "      (lambda (ws)\n" +
        "        (let loop ((m (ws-receive ws)))\n" +
        "          (when m (ws-send ws m) (loop (ws-receive ws))))))))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        Lambda handler = Value.AsLambda(arguments[0]);
        var headers = arguments.Length > 1 ? PrimitiveMakeHttpResponse.ParseHeaders(arguments[1]) : new List<(string, string)>();
        return new NativeValue(SchemeHttpResponse.OfWebSocket(headers, handler));
    }
}
