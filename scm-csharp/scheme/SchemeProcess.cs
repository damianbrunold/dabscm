using System;
using System.Diagnostics;

namespace scheme;

public class SchemeProcess
{
    public Process process;

    // Windows-only: handle of the Job Object this process is assigned to, or
    // IntPtr.Zero if none (non-Windows, or job creation failed). process-kill
    // terminates the whole job, killing the entire descendant tree at once.
    public IntPtr jobHandle = IntPtr.Zero;

    public SchemeProcess(Process process) { this.process = process; }

    public override string ToString() => $"#<process {process.Id}>";
}
