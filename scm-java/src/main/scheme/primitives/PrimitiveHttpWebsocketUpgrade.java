package scheme.primitives;

import scheme.*;
import java.util.ArrayList;

public class PrimitiveHttpWebsocketUpgrade extends Primitive {
    @Override
    public String name() { return "http-websocket-upgrade"; }

    @Override
    public String info() {
        return "Syntax: (http-websocket-upgrade handler [headers])\n" +
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
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        Lambda handler = Value.asLambda(arguments[0]);
        var headers = arguments.length > 1 ? PrimitiveMakeHttpResponse.parseHeaders(arguments[1]) : new ArrayList<String[]>();
        return new NativeValue(SchemeHttpResponse.ofWebSocket(headers, handler));
    }
}
