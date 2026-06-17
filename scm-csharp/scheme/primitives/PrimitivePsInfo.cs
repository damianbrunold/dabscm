using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace scheme;

public class PrimitivePsInfo : Primitive
{
    public override string Name() => "ps-info";

    public override string Info() =>
        "Syntax: (ps-info pid)\n" +
        "Library: (scm system)\n" +
        "Description: Returns an alist describing the process with the given pid, or #f\n" +
        "  if no such process exists or it cannot be inspected. See (ps) for the\n" +
        "  field set.\n" +
        "Example:\n" +
        "  (cdr (assq 'command (ps-info (current-pid)))) => \"scm\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        long pid = IntegerMath.ToLong(arguments[0]);
        Process? p;
        try { p = Process.GetProcessById((int) pid); }
        catch (Exception) { return Value.F; }
        if (p == null) return Value.F;
        bool linux = RuntimeInformation.IsOSPlatform(OSPlatform.Linux);
        Dictionary<int, int>? ppidMap =
            RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? ProcUtil.WindowsPpidMap() : null;
        try
        {
            return PsPrimitiveHelpers.BuildInfo(p, linux, ppidMap);
        }
        finally { p.Dispose(); }
    }
}
