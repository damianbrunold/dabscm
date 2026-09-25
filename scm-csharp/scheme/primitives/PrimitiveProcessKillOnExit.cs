using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

namespace scheme;

public class PrimitiveProcessKillOnExit : Primitive
{
    // Children registered to be killed when this process exits. Shared across
    // all calls so a single set of exit handlers suffices.
    private static readonly ConcurrentDictionary<int, Process> Tracked = new();
    private static int handlersInstalled = 0;
    // Set once the exit handlers have fired. A child registered after that
    // point (the supervisor's main thread racing the signal, e.g. mid-restart)
    // would never be killed, so it is killed on registration instead.
    private static volatile bool exiting = false;
    // PosixSignalRegistration unregisters when collected; keep them rooted.
    private static PosixSignalRegistration[]? registrations;

    public override string Name() => "process-kill-on-exit";

    public override string Info() =>
        "Syntax: (process-kill-on-exit handle)\n" +
        "Library: (scm system)\n" +
        "Description: Registers a process started by start-program to be killed " +
        "forcefully when this (parent) process exits, via OS-level handlers fired on " +
        "Ctrl+C / SIGINT, process exit / SIGTERM and SIGHUP. Prevents orphaned " +
        "children — e.g. a dev supervisor's server child left holding a port after the " +
        "supervisor is stopped. Already-exited handles are pruned, so the registry " +
        "stays bounded across repeated restarts. Returns #t.\n" +
        "Example:\n" +
        "  (define p (start-program '(\"scm\" \"server.scm\")))\n" +
        "  (process-kill-on-exit p)";

    private static void KillTree(Process p)
    {
        // Tree-kill: the tracked handle is often a wrapper whose grandchild
        // holds the port, and a plain Kill() spares descendants.
        try { if (!p.HasExited) p.Kill(entireProcessTree: true); } catch { }
    }

    private static void KillAll()
    {
        exiting = true;
        foreach (var kv in Tracked) KillTree(kv.Value);
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeProcess sp = (SchemeProcess) Value.AsNativeValue(arguments[0]).value;

        // Prune dead entries so the set stays bounded across many restarts.
        foreach (var kv in Tracked)
        {
            try { if (kv.Value.HasExited) Tracked.TryRemove(kv.Key, out _); }
            catch { Tracked.TryRemove(kv.Key, out _); }
        }
        Tracked[sp.process.Id] = sp.process;
        if (exiting) KillTree(sp.process);

        if (Interlocked.Exchange(ref handlersInstalled, 1) == 0)
        {
            // Kill the children, then let the signal's default action terminate
            // this process — i.e. do NOT set context.Cancel. (Cancelling Ctrl+C
            // used to leave a supervisor such as (scm reloader) running: it saw
            // its child die and simply restarted it, so Ctrl+C never stopped it.)
            // This matches the JVM, whose shutdown hooks run and then exit.
            // On Windows, SIGINT/SIGQUIT map to Ctrl+C/Ctrl+Break, SIGHUP to the
            // console window closing and SIGTERM to logoff/shutdown.
            registrations = new[]
            {
                PosixSignalRegistration.Create(PosixSignal.SIGINT,  _ => KillAll()),
                PosixSignalRegistration.Create(PosixSignal.SIGQUIT, _ => KillAll()),
                PosixSignalRegistration.Create(PosixSignal.SIGTERM, _ => KillAll()),
                PosixSignalRegistration.Create(PosixSignal.SIGHUP,  _ => KillAll()),
            };
            AppDomain.CurrentDomain.ProcessExit += (sender, e) => KillAll();
        }
        return Value.T;
    }
}
