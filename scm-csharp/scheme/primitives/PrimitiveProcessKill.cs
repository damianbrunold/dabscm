using System;
using System.Runtime.InteropServices;

namespace scheme;

public class PrimitiveProcessKill : Primitive
{
    public override string Name() => "process-kill";

    public override string Info() =>
        "Syntax: (process-kill handle [force?])\n" +
        "Library: (scm system)\n" +
        "Description: Stops a process started by start-program. With force? = #f " +
        "(default) sends SIGTERM on Unix, allowing the child to drain gracefully; " +
        "on Windows, console processes have no graceful-kill API so this " +
        "currently behaves as a forceful kill. With force? = #t always kills " +
        "forcefully (SIGKILL on Unix). Returns #t.\n" +
        "Example:\n" +
        "  (process-kill p)        ; graceful where supported\n" +
        "  (process-kill p #t)     ; force";

    [DllImport("libc", SetLastError = true)]
    private static extern int kill(int pid, int sig);
    private const int SIGTERM = 15;

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        SchemeProcess sp = (SchemeProcess) Value.AsNativeValue(arguments[0]).value;
        bool force = arguments.Length > 1 && !arguments[1].Equals(Value.F);

        if (sp.process.HasExited) return Value.T;

        try
        {
            if (!force && !RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                // POSIX: deliver SIGTERM so the child can run its shutdown
                // hook (e.g. drain HTTP requests) before exiting.
                kill(sp.process.Id, SIGTERM);
            }
            else
            {
                // Forceful — and the only option for console processes on Windows.
                // Kill the whole tree: on Windows the child is often a wrapper
                // (cmd.exe/scm.bat) whose grandchild holds the port, and a plain
                // Kill() spares descendants, leaving the port bound.
                sp.process.Kill(entireProcessTree: true);
            }
        }
        catch (InvalidOperationException) { /* already exited */ }
        catch (Exception) { /* tolerate platform quirks */ }
        return Value.T;
    }
}
