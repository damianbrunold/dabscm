using System.Diagnostics;

namespace scheme;

public class SchemeProcess
{
    public Process process;

    public SchemeProcess(Process process) { this.process = process; }

    public override string ToString() => $"#<process {process.Id}>";
}
