package scheme;

import java.io.InputStream;
import java.io.OutputStream;

public class SchemeWebSocket {
    public InputStream input;
    public OutputStream output;
    public boolean isServer;

    public SchemeWebSocket(InputStream input, OutputStream output, boolean isServer) {
        this.input = input;
        this.output = output;
        this.isServer = isServer;
    }

    @Override
    public String toString() { return "#<websocket>"; }
}
