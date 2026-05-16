package scheme.primitives;
import scheme.*;
import java.io.*;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.UUID;

public class PrimitiveWsConnect extends Primitive {
    @Override
    public String name() { return "ws-connect"; }

    @Override
    public String info() {
        return "Syntax: (ws-connect host port path)\n" +
               "Library: (scm net websocket)\n" +
               "Description: Connects to a WebSocket server (RFC 6455 client handshake). Returns a WebSocket object.\n" +
               "Example:\n" +
               "  (define ws (ws-connect \"localhost\" 8080 \"/ws\"))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        String host = new String(Value.asString(arguments[0]));
        int port = IntegerMath.toInt(arguments[1]);
        String path = new String(Value.asString(arguments[2]));
        try {
            Socket socket = new Socket(host, port);
            InputStream rawIn = socket.getInputStream();
            OutputStream rawOut = socket.getOutputStream();
            String key = Base64.getEncoder().encodeToString(UUID.randomUUID().toString().getBytes());
            String request = "GET " + path + " HTTP/1.1\r\n" +
                "Host: " + host + ":" + port + "\r\n" +
                "Upgrade: websocket\r\n" +
                "Connection: Upgrade\r\n" +
                "Sec-WebSocket-Key: " + key + "\r\n" +
                "Sec-WebSocket-Version: 13\r\n\r\n";
            rawOut.write(request.getBytes(StandardCharsets.UTF_8));
            rawOut.flush();
            BufferedReader reader = new BufferedReader(new InputStreamReader(rawIn, StandardCharsets.UTF_8));
            String line;
            while ((line = reader.readLine()) != null && !line.isEmpty()) { /* drain */ }
            return new NativeValue(new SchemeWebSocket(rawIn, rawOut, false));
        } catch (Exception e) { throw new SchemeError(pos, "ws-connect: " + e.getMessage()); }
    }
}
