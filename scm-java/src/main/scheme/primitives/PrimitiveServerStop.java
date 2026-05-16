package scheme.primitives;
import scheme.*;
import java.util.concurrent.TimeUnit;

public class PrimitiveServerStop extends Primitive {
    @Override
    public String name() { return "server-stop"; }

    @Override
    public String info() {
        return "Syntax: (server-stop server [graceful-ms])\n" +
               "Library: (scm net http server)\n" +
               "Description: Stops a running HTTP server. Stops accepting new connections, then waits " +
               "up to graceful-ms for in-flight requests to complete (default: the server's configured " +
               "graceful-stop-ms). Returns #t once the listener has been closed.\n" +
               "Example:\n" +
               "  (server-stop s)\n" +
               "  (server-stop s 5000)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        SchemeServer s = (SchemeServer) Value.asNativeValue(arguments[0]).value;
        int graceMs = arguments.length > 1 ? IntegerMath.toInt(arguments[1]) : s.gracefulStopMs;
        if (graceMs < 0) graceMs = 0;

        s.running.set(false);
        if (s.serverSocket != null) {
            try { s.serverSocket.close(); } catch (Exception ignored) {}
        }
        if (s.executor != null) {
            s.executor.shutdown();
            try {
                if (!s.executor.awaitTermination(graceMs, TimeUnit.MILLISECONDS)) {
                    s.executor.shutdownNow();
                }
            } catch (InterruptedException ie) {
                s.executor.shutdownNow();
                Thread.currentThread().interrupt();
            }
        }
        return Value.T;
    }
}
