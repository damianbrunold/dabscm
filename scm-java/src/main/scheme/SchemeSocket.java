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
            new java.io.PushbackReader(new BufferedReader(new InputStreamReader(networkInputStream), 8192)),
            "{socket}");
        this.outputPort = new TextOutputStream(new BufferedWriter(new OutputStreamWriter(networkOutputStream), 8192));
    }

    public SchemeSocket(Socket socket, InputStream in, OutputStream out) throws IOException {
        this.socket = socket;
        this.networkInputStream = in;
        this.networkOutputStream = out;
        this.inputPort = new TextStream(
            new java.io.PushbackReader(new BufferedReader(new InputStreamReader(in), 8192)),
            "{socket}");
        this.outputPort = new TextOutputStream(new BufferedWriter(new OutputStreamWriter(out), 8192));
    }

    @Override
    public String toString() { return "#<socket>"; }
}
