using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace scheme;

public class PrimitivePgrep : Primitive
{
    public override string Name() => "pgrep";

    public override string Info() =>
        "Syntax: (pgrep pattern [full?])\n" +
        "Library: (scm system)\n" +
        "Description: Returns a list of pids whose command matches the substring\n" +
        "  pattern. By default matches against the process name. If full? is #t,\n" +
        "  matches against the full command line (where the platform supplies it).\n" +
        "  Pattern matching is case-sensitive substring.\n" +
        "Example:\n" +
        "  (pgrep \"java\") => (1234 5678)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        string pattern = new string(Value.AsString(arguments[0]));
        bool full = arguments.Length > 1 && !arguments[1].Equals(Value.F);
        bool linux = RuntimeInformation.IsOSPlatform(OSPlatform.Linux);
        object result = Value.NIL;
        Process[] procs;
        try { procs = Process.GetProcesses(); }
        catch (Exception) { return Value.NIL; }
        foreach (Process p in procs)
        {
            try
            {
                string? hay = null;
                if (full && linux) hay = ProcUtil.ReadCmdline(p.Id.ToString());
                if (string.IsNullOrEmpty(hay)) hay = p.ProcessName;
                if (!string.IsNullOrEmpty(hay) && hay!.Contains(pattern))
                {
                    result = new Pair((long) p.Id, result);
                }
            }
            catch (Exception) { }
            finally { p.Dispose(); }
        }
        return result;
    }
}
