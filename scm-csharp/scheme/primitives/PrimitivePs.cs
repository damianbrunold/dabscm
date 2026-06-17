using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace scheme;

public class PrimitivePs : Primitive
{
    public override string Name() => "ps";

    public override string Info() =>
        "Syntax: (ps)\n" +
        "Library: (scm system)\n" +
        "Description: Returns a list of alists describing the processes currently visible\n" +
        "  on the system. Each alist has the keys:\n" +
        "    pid         — process id (integer)\n" +
        "    ppid        — parent pid (integer) or #f if unavailable\n" +
        "    command     — process command/name as a string\n" +
        "    user        — owning user (string) or uid (integer) or #f\n" +
        "    start-time  — epoch milliseconds (integer) or #f\n" +
        "    cpu-time    — accumulated cpu time in seconds (inexact) or #f\n" +
        "  Fields that the platform cannot supply or that the current user cannot\n" +
        "  access are #f. Order is unspecified.\n" +
        "Example:\n" +
        "  (length (ps)) => 312";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        object result = Value.NIL;
        Process[] procs;
        try { procs = Process.GetProcesses(); }
        catch (Exception) { return Value.NIL; }
        bool linux = RuntimeInformation.IsOSPlatform(OSPlatform.Linux);
        bool windows = RuntimeInformation.IsOSPlatform(OSPlatform.Windows);
        // .NET's Process exposes no parent pid; on Windows take one toolhelp
        // snapshot for the whole pid -> ppid map (#f-valued elsewhere).
        Dictionary<int, int>? ppidMap = windows ? ProcUtil.WindowsPpidMap() : null;
        foreach (Process p in procs)
        {
            try
            {
                result = new Pair(PsPrimitiveHelpers.BuildInfo(p, linux, ppidMap), result);
            }
            catch (Exception) { /* skip processes that vanish mid-iteration */ }
            finally { p.Dispose(); }
        }
        return result;
    }
}

internal static class PsPrimitiveHelpers
{
    public static object BuildInfo(Process p, bool linux, Dictionary<int, int>? ppidMap)
    {
        long pid = p.Id;
        string pidStr = pid.ToString();
        object ppid = Value.F;
        object user = Value.F;
        if (linux)
        {
            long? pp = ProcUtil.ReadPpid(pidStr);
            if (pp.HasValue) ppid = (long) pp.Value;
            long? uid = ProcUtil.ReadUid(pidStr);
            if (uid.HasValue) user = (long) uid.Value;
        }
        else if (ppidMap != null && ppidMap.TryGetValue((int) pid, out int wppid))
        {
            ppid = (long) wppid;
        }
        object command = Value.F;
        try
        {
            string? cmd = linux ? ProcUtil.ReadCmdline(pidStr) : null;
            if (string.IsNullOrEmpty(cmd)) cmd = p.ProcessName;
            if (!string.IsNullOrEmpty(cmd)) command = cmd!.ToCharArray();
        }
        catch (Exception) { }
        object startTime = Value.F;
        try { startTime = (long) ((DateTimeOffset) p.StartTime).ToUnixTimeMilliseconds(); }
        catch (Exception) { }
        object cpuTime = Value.F;
        try { cpuTime = p.TotalProcessorTime.TotalSeconds; }
        catch (Exception) { }
        return Pair.List(
            new Pair(Value.Intern("pid"), (long) pid),
            new Pair(Value.Intern("ppid"), ppid),
            new Pair(Value.Intern("command"), command),
            new Pair(Value.Intern("user"), user),
            new Pair(Value.Intern("start-time"), startTime),
            new Pair(Value.Intern("cpu-time"), cpuTime));
    }
}
