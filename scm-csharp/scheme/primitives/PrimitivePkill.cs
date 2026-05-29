using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace scheme;

public class PrimitivePkill : Primitive
{
    public override string Name() => "pkill";

    public override string Info() =>
        "Syntax: (pkill pattern [force? [full?]])\n" +
        "Library: (scm system)\n" +
        "Description: Sends a termination request to every process whose command matches\n" +
        "  the substring pattern. By default matches against the process name; if full?\n" +
        "  is #t, matches against the full command line. With force? = #t kills\n" +
        "  forcefully (SIGKILL on Unix). Returns the number of processes that were\n" +
        "  successfully signaled. Does NOT match the current Scheme process.\n" +
        "Example:\n" +
        "  (pkill \"sleep\") => 2";

    [DllImport("libc", SetLastError = true)]
    private static extern int kill(int pid, int sig);
    private const int SIGTERM = 15;
    private const int SIGKILL = 9;

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        string pattern = new string(Value.AsString(arguments[0]));
        bool force = arguments.Length > 1 && !arguments[1].Equals(Value.F);
        bool full = arguments.Length > 2 && !arguments[2].Equals(Value.F);
        bool linux = RuntimeInformation.IsOSPlatform(OSPlatform.Linux);
        bool windows = RuntimeInformation.IsOSPlatform(OSPlatform.Windows);
        int self = Process.GetCurrentProcess().Id;
        long count = 0;
        Process[] procs;
        try { procs = Process.GetProcesses(); }
        catch (Exception) { return (long) 0; }
        foreach (Process p in procs)
        {
            try
            {
                if (p.Id == self) continue;
                string? hay = null;
                if (full && linux) hay = ProcUtil.ReadCmdline(p.Id.ToString());
                if (string.IsNullOrEmpty(hay)) hay = p.ProcessName;
                if (string.IsNullOrEmpty(hay) || !hay!.Contains(pattern)) continue;
                if (!windows)
                {
                    if (kill(p.Id, force ? SIGKILL : SIGTERM) == 0) count++;
                }
                else
                {
                    p.Kill();
                    count++;
                }
            }
            catch (Exception) { }
            finally { p.Dispose(); }
        }
        return count;
    }
}
