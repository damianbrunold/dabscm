package scheme;

import java.net.ServerSocket;

public class SchemeListener {
    public ServerSocket serverSocket;

    public SchemeListener(ServerSocket ss) {
        this.serverSocket = ss;
    }

    @Override
    public String toString() { return "#<tcp-listener>"; }
}
