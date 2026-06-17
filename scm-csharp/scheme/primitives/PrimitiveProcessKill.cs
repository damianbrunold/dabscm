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

        if (sp.process.HasExited) { sp.CloseLog(); return Value.T; }

        // POSIX, non-forceful: SIGTERM so the child can drain gracefully. The log
        // stays open — the child keeps writing until it exits; process-wait
        // closes it then.
        bool graceful = !force && !RuntimeInformation.IsOSPlatform(OSPlatform.Windows);
        try
        {
            if (graceful)
            {
                kill(sp.process.Id, SIGTERM);
            }
            else
            {
                // Forceful path (always on Windows, where console processes have
                // no graceful-close API). Mirror the Python original, which
                // enumerated the whole tree and TerminateProcess'd every pid:
                // rely on the framework tree-walk, which works even where the Job
                // Object is ineffective (e.g. the child is already job-contained
                // on a locked-down box, so AssignProcessToJobObject was refused).
                // Terminate the job too when we have one — a race-free bonus, not
                // the sole mechanism it used to be.
                if (sp.jobHandle != IntPtr.Zero)
                {
                    try { WindowsJobObject.Terminate(sp.jobHandle); } catch { /* already gone */ }
                    sp.jobHandle = IntPtr.Zero;
                }
                try { sp.process.Kill(entireProcessTree: true); }
                catch (InvalidOperationException) { /* already exited */ }
            }
        }
        catch (InvalidOperationException) { /* already exited */ }
        catch (Exception) { /* tolerate platform quirks */ }

        // After a forceful stop the child is gone, so release the log handle now
        // (a graceful SIGTERM leaves it draining; process-wait closes it then).
        if (!graceful) sp.CloseLog();
        return Value.T;
    }
}
