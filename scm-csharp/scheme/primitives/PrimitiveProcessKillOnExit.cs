using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Threading;

namespace scheme;

public class PrimitiveProcessKillOnExit : Primitive
{
    // Children registered to be killed when this process exits. Shared across
    // all calls so a single set of exit handlers suffices.
    private static readonly ConcurrentDictionary<int, Process> Tracked = new();
    private static int handlersInstalled = 0;

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

    private static void KillAll()
    {
        foreach (var kv in Tracked)
        {
            // Tree-kill: the tracked handle is often a wrapper whose grandchild
            // holds the port, and a plain Kill() spares descendants.
            try { if (!kv.Value.HasExited) kv.Value.Kill(entireProcessTree: true); } catch { }
        }
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

        if (Interlocked.Exchange(ref handlersInstalled, 1) == 0)
        {
            Console.CancelKeyPress += (sender, e) => { e.Cancel = true; KillAll(); };
            AppDomain.CurrentDomain.ProcessExit += (sender, e) => KillAll();
        }
        return Value.T;
    }
}
