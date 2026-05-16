package scheme.primitives;
import scheme.*;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

public class PrimitiveServerInstallShutdownHook extends Primitive {
    @Override
    public String name() { return "server-install-shutdown-hook"; }

    @Override
    public String info() {
        return "Syntax: (server-install-shutdown-hook server [graceful-ms])\n" +
               "Library: (scm net http server)\n" +
               "Description: Installs an OS-level handler (JVM shutdown hook, fired on SIGINT and " +
               "SIGTERM) that stops the given server with the configured graceful drain. Suitable " +
               "for use under systemd, where SIGTERM should drain in-flight requests before the " +
               "process exits. Returns #t.\n" +
               "Example:\n" +
               "  (define s (tcp-http-serve 8080 handler))\n" +
               "  (server-install-shutdown-hook s 5000)\n" +
               "  (server-wait s)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        SchemeServer s = (SchemeServer) Value.asNativeValue(arguments[0]).value;
        int graceMs = arguments.length > 1 ? IntegerMath.toInt(arguments[1]) : s.gracefulStopMs;
        if (graceMs < 0) graceMs = 0;
        final int graceMsF = graceMs;

        AtomicBoolean stopped = new AtomicBoolean(false);
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            if (!stopped.compareAndSet(false, true)) return;
            s.running.set(false);
            if (s.serverSocket != null) {
                try { s.serverSocket.close(); } catch (Exception ignored) {}
            }
            if (s.executor != null) {
                s.executor.shutdown();
                try {
                    if (!s.executor.awaitTermination(graceMsF, TimeUnit.MILLISECONDS)) {
                        s.executor.shutdownNow();
                    }
                } catch (InterruptedException ie) {
                    s.executor.shutdownNow();
                    Thread.currentThread().interrupt();
                }
            }
        }));
        return Value.T;
    }
}
