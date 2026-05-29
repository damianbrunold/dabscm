using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace scheme;

public class PrimitiveKill : Primitive
{
    public override string Name() => "kill";

    public override string Info() =>
        "Syntax: (kill pid [force?])\n" +
        "Library: (scm system)\n" +
        "Description: Sends a termination request to the process with the given pid.\n" +
        "  With force? = #f (default) sends SIGTERM on Unix; on Windows there is no\n" +
        "  graceful kill for console processes so the call falls back to a forceful\n" +
        "  kill. With force? = #t always kills forcefully (SIGKILL on Unix).\n" +
        "  Returns #t if the request was delivered, #f if the process does not exist\n" +
        "  or the caller lacks permission to signal it.\n" +
        "Example:\n" +
        "  (kill 12345)        ; graceful\n" +
        "  (kill 12345 #t)     ; force";

    [DllImport("libc", SetLastError = true)]
    private static extern int kill(int pid, int sig);
    private const int SIGTERM = 15;
    private const int SIGKILL = 9;

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        int pid = (int) IntegerMath.ToLong(arguments[0]);
        bool force = arguments.Length > 1 && !arguments[1].Equals(Value.F);
        try
        {
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                int r = kill(pid, force ? SIGKILL : SIGTERM);
                return r == 0 ? Value.T : Value.F;
            }
            using Process p = Process.GetProcessById(pid);
            p.Kill();
            return Value.T;
        }
        catch (Exception) { return Value.F; }
    }
}
