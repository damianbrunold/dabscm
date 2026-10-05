namespace scheme;

public class PrimitiveSysScmCommand : Primitive
{
    public override string Name() => "sys-scm-command";

    public override string Info() =>
        "Syntax: (sys-scm-command)\n" +
        "Library: (scm system)\n" +
        "Description: Returns the command line (a list of strings) that starts the currently running SCM interpreter. Append a script path and its arguments to run it with the same implementation (java or csharp) and installation, independent of what scm is on PATH.\n" +
        "Example:\n" +
        "  (sys-scm-command) => (\"/opt/dabscm/scm\")\n" +
        "  (run-program (append (sys-scm-command) (list \"build.scm\")))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        var cmd = new List<string>();
        var process = Environment.ProcessPath ?? "scm";
        cmd.Add(process);
        // started as `dotnet scm.dll`: the host needs the entry assembly too
        var host = Path.GetFileNameWithoutExtension(process);
        if (string.Equals(host, "dotnet", StringComparison.OrdinalIgnoreCase))
        {
            var entry = System.Reflection.Assembly.GetEntryAssembly()?.Location;
            if (!string.IsNullOrEmpty(entry)) cmd.Add(entry);
        }
        return Pair.List(cmd.Select(s => (object) s.ToCharArray()).ToArray());
    }
}
