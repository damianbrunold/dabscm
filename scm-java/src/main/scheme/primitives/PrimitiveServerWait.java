package scheme.primitives;
import scheme.*;

public class PrimitiveServerWait extends Primitive {
    @Override
    public String name() { return "server-wait"; }

    @Override
    public String info() {
        return "Syntax: (server-wait server)\n" +
               "Library: (scm net http server)\n" +
               "Description: Blocks the calling thread until the given HTTP server has stopped. " +
               "Returns when the server's accept loop has exited, e.g. after server-stop.\n" +
               "Example:\n" +
               "  (server-wait s)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeServer s = (SchemeServer) Value.asNativeValue(arguments[0]).value;
        if (s.thread != null) {
            try { s.thread.join(); } catch (InterruptedException ignored) { Thread.currentThread().interrupt(); }
        }
        return Value.T;
    }
}
