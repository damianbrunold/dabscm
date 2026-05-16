package scheme;

import java.io.*;
import java.net.Socket;

public class SchemeSocket {
    public Socket socket;
    public TextStream inputPort;
    public TextOutputStream outputPort;
    public InputStream networkInputStream;
    public OutputStream networkOutputStream;
    public BinaryInputStream binaryInputPort;
    public BinaryOutputStream binaryOutputPort;

    public SchemeSocket(Socket socket) throws IOException {
        this.socket = socket;
        this.networkInputStream = socket.getInputStream();
        this.networkOutputStream = socket.getOutputStream();
        this.inputPort = new TextStream(
            new java.io.PushbackReader(new InputStreamReader(networkInputStream)),
            "{socket}");
        this.outputPort = new TextOutputStream(new OutputStreamWriter(networkOutputStream));
    }

    public SchemeSocket(Socket socket, InputStream in, OutputStream out) throws IOException {
        this.socket = socket;
        this.networkInputStream = in;
        this.networkOutputStream = out;
        this.inputPort = new TextStream(
            new java.io.PushbackReader(new InputStreamReader(in)),
            "{socket}");
        this.outputPort = new TextOutputStream(new OutputStreamWriter(out));
    }

    @Override
    public String toString() { return "#<socket>"; }
}
