using System;
using System.Threading;

namespace scheme;

public class PrimitiveServerInstallShutdownHook : Primitive
{
    public override string Name() => "server-install-shutdown-hook";

    public override string Info() =>
        "Syntax: (server-install-shutdown-hook server [graceful-ms])\n" +
        "Library: (scm net http server)\n" +
        "Description: Installs OS-level handlers (Ctrl+C / SIGINT and process exit / SIGTERM) " +
        "that stop the given server with the configured graceful drain. Suitable for use under " +
        "systemd, where SIGTERM should drain in-flight requests before the process exits. " +
        "Returns #t.\n" +
        "Example:\n" +
        "  (define s (tcp-http-serve 8080 handler))\n" +
        "  (server-install-shutdown-hook s 5000)\n" +
        "  (server-wait s)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        SchemeServer s = (SchemeServer) Value.AsNativeValue(arguments[0]).value;
        int graceMs = arguments.Length > 1 ? IntegerMath.ToInt(arguments[1]) : s.gracefulStopMs;
        if (graceMs < 0) graceMs = 0;

        int alreadyStopped = 0;
        void Stop()
        {
            if (Interlocked.Exchange(ref alreadyStopped, 1) != 0) return;
            try { s.cts.Cancel(); } catch { }
            try { s.listener.Stop(); } catch { }
            if (s.sem != null && s.maxThreads > 0)
            {
                var deadline = DateTime.UtcNow.AddMilliseconds(graceMs);
                while (DateTime.UtcNow < deadline)
                {
                    if (s.sem.CurrentCount >= s.maxThreads) break;
                    Thread.Sleep(50);
                }
            }
        }

        Console.CancelKeyPress += (sender, e) => { e.Cancel = true; Stop(); };
        AppDomain.CurrentDomain.ProcessExit += (sender, e) => Stop();
        return Value.T;
    }
}
