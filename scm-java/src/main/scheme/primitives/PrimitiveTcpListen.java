package scheme.primitives;
import scheme.*;
import java.net.ServerSocket;

public class PrimitiveTcpListen extends Primitive {
    @Override
    public String name() { return "tcp-listen"; }

    @Override
    public String info() {
        return "Syntax: (tcp-listen port)\n" +
               "Library: (scm net sockets)\n" +
               "Description: Creates a TCP listener on the given port and starts listening for connections.\n" +
               "Example:\n" +
               "  (define l (tcp-listen 8080))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        int port = IntegerMath.toInt(arguments[0]);
        try {
            ServerSocket ss = new ServerSocket(port);
            return new NativeValue(new SchemeListener(ss));
        } catch (Exception e) {
            throw new SchemeError(pos, "tcp-listen: " + e.getMessage());
        }
    }
}
