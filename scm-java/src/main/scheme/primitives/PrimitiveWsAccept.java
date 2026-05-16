package scheme.primitives;
import scheme.*;
import java.io.*;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;

public class PrimitiveWsAccept extends Primitive {
    @Override
    public String name() { return "ws-accept"; }

    @Override
    public String info() {
        return "Syntax: (ws-accept socket)\n" +
               "Library: (scm net websocket)\n" +
               "Description: Performs a WebSocket server-side handshake (RFC 6455) on the given TCP socket. Returns a WebSocket object.\n" +
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
            BufferedReader reader = new BufferedReader(new InputStreamReader(rawIn, StandardCharsets.UTF_8));
            String wsKey = null;
            String line;
            while ((line = reader.readLine()) != null && !line.isEmpty()) {
                if (line.toLowerCase().startsWith("sec-websocket-key:"))
                    wsKey = line.substring(line.indexOf(':') + 1).trim();
            }
            if (wsKey == null)
                throw new SchemeError(pos, "ws-accept: missing Sec-WebSocket-Key header");
            String combined = wsKey + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
            byte[] sha1 = MessageDigest.getInstance("SHA-1").digest(combined.getBytes(StandardCharsets.UTF_8));
            String accept = Base64.getEncoder().encodeToString(sha1);
            String response = "HTTP/1.1 101 Switching Protocols\r\n" +
                "Upgrade: websocket\r\n" +
                "Connection: Upgrade\r\n" +
                "Sec-WebSocket-Accept: " + accept + "\r\n\r\n";
            rawOut.write(response.getBytes(StandardCharsets.UTF_8));
            rawOut.flush();
            return new NativeValue(new SchemeWebSocket(rawIn, rawOut, true));
        } catch (SchemeError e) { throw e; }
        catch (Exception e) { throw new SchemeError(pos, "ws-accept: " + e.getMessage()); }
    }
}
