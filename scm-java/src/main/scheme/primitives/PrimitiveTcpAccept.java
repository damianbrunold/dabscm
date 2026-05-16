package scheme.primitives;
import scheme.*;
import java.net.Socket;

public class PrimitiveTcpAccept extends Primitive {
    @Override
    public String name() { return "tcp-accept"; }

    @Override
    public String info() {
        return "Syntax: (tcp-accept listener)\n" +
               "Library: (scm net sockets)\n" +
               "Description: Accepts an incoming TCP connection on the listener. Blocks until a connection arrives.\n" +
               "Example:\n" +
               "  (define sock (tcp-accept listener))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeListener sl = (SchemeListener) Value.asNativeValue(arguments[0]).value;
        try {
            Socket client = sl.serverSocket.accept();
            return new NativeValue(new SchemeSocket(client));
        } catch (Exception e) {
            throw new SchemeError(pos, "tcp-accept: " + e.getMessage());
        }
    }
}
