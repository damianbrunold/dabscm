using System;
using System.Threading;

namespace scheme;

public class PrimitiveServerStop : Primitive
{
    public override string Name() => "server-stop";

    public override string Info() =>
        "Syntax: (server-stop server [graceful-ms])\n" +
        "Library: (scm net http server)\n" +
        "Description: Stops a running HTTP server. Stops accepting new connections, then waits " +
        "up to graceful-ms for in-flight requests to complete (default: the server's configured " +
        "graceful-stop-ms). Returns #t once the listener has been closed.\n" +
        "Example:\n" +
        "  (server-stop s)\n" +
        "  (server-stop s 5000)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        SchemeServer s = (SchemeServer) Value.AsNativeValue(arguments[0]).value;
        int graceMs = arguments.Length > 1 ? IntegerMath.ToInt(arguments[1]) : s.gracefulStopMs;
        if (graceMs < 0) graceMs = 0;

        s.cts.Cancel();
        try { s.listener.Stop(); } catch { }

        // Drain in-flight requests by waiting for the semaphore to refill to its
        // initial capacity, up to the grace period. After that, give up — the
        // process will exit and any remaining requests will be cut.
        if (s.sem != null && s.maxThreads > 0)
        {
            var deadline = DateTime.UtcNow.AddMilliseconds(graceMs);
            while (DateTime.UtcNow < deadline)
            {
                if (s.sem.CurrentCount >= s.maxThreads) break;
                Thread.Sleep(50);
            }
        }
        return Value.T;
    }
}
