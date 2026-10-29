package scheme.primitives;
import scheme.*;
import java.io.*;
import java.nio.charset.StandardCharsets;

public class PrimitiveWsAccept extends Primitive {
    @Override
    public String name() { return "ws-accept"; }

    @Override
    public String info() {
        return "Syntax: (ws-accept socket)\n" +
               "Library: (scm net websocket)\n" +
               "Description: Performs a WebSocket server-side handshake (RFC 6455) on the given TCP socket. Returns a WebSocket object.\n" +
               "  In an HTTP server, use http-websocket-upgrade instead.\n" +
               "Example:\n" +
               "  (define ws (ws-accept sock))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeSocket ss = (SchemeSocket) Value.asNativeValue(arguments[0]).value;
        try {
            InputStream rawIn = ss.socket.getInputStream();
            OutputStream rawOut = ss.socket.getOutputStream();
            String headers = SchemeWebSocket.readHeaders(rawIn);
            String wsKey = null;
            if (headers != null) {
                for (String line : headers.split("\r\n")) {
                    if (line.toLowerCase().startsWith("sec-websocket-key:"))
                        wsKey = line.substring(line.indexOf(':') + 1).trim();
                }
            }
            if (wsKey == null)
                throw new SchemeError(pos, "ws-accept: missing Sec-WebSocket-Key header");
            String response = "HTTP/1.1 101 Switching Protocols\r\n" +
                "Upgrade: websocket\r\n" +
                "Connection: Upgrade\r\n" +
                "Sec-WebSocket-Accept: " + SchemeWebSocket.acceptKey(wsKey) + "\r\n\r\n";
            rawOut.write(response.getBytes(StandardCharsets.UTF_8));
            rawOut.flush();
            return new NativeValue(new SchemeWebSocket(rawIn, rawOut, true, ss.socket));
        } catch (SchemeError e) { throw e; }
        catch (Exception e) { throw new SchemeError(pos, "ws-accept: " + e.getMessage()); }
    }
}
