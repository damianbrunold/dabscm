package scheme.primitives;
import scheme.*;

public class PrimitiveSocketClose extends Primitive {
    @Override
    public String name() { return "socket-close"; }

    @Override
    public String info() {
        return "Syntax: (socket-close socket-or-listener)\n" +
               "Library: (scm net sockets)\n" +
               "Description: Closes a socket or TCP listener.\n" +
               "Example:\n" +
               "  (socket-close sock)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (!Value.isNativeValue(arguments[0]))
            throw new SchemeError(pos, "socket-close: expected socket or listener");
        Object inner = Value.asNativeValue(arguments[0]).value;
        try {
            if (inner instanceof SchemeSocket) { ((SchemeSocket) inner).socket.close(); }
            else if (inner instanceof SchemeListener) { ((SchemeListener) inner).serverSocket.close(); }
            else throw new SchemeError(pos, "socket-close: expected socket or listener");
        } catch (SchemeError e) { throw e; }
        catch (Exception e) { /* ignore close errors */ }
        return Value.T;
    }
}
