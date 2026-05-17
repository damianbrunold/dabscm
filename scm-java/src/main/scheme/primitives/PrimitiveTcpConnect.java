package scheme.primitives;
import scheme.*;
import java.net.Socket;

public class PrimitiveTcpConnect extends Primitive {
    @Override
    public String name() { return "tcp-connect"; }

    @Override
    public String info() {
        return "Syntax: (tcp-connect host port)\n" +
               "Library: (scm net sockets)\n" +
               "Description: Connects to a TCP server at the given host and port. Returns a socket.\n" +
               "Example:\n" +
               "  (define sock (tcp-connect \"localhost\" 8080))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        String host = new String(Value.asString(arguments[0]));
        int port = IntegerMath.toInt(arguments[1]);
        try {
            Socket client = new Socket(host, port);
            // Disable Nagle's algorithm. Default-on Nagle interacts
            // with the peer's delayed-ACK to add ~40 ms to every small
            // request (typical of RPC-style protocols like postgres
            // wire). Almost every TCP client in this runtime wants
            // this off; the cost is a few more outgoing packets in
            // bursty workloads.
            client.setTcpNoDelay(true);
            return new NativeValue(new SchemeSocket(client));
        } catch (Exception e) {
            throw new SchemeError(pos, "tcp-connect: " + e.getMessage());
        }
    }
}
