namespace scheme;

using System.Reflection;

public class PrimitiveSysScmVersion : Primitive
{
    public override string Name() => "sys-scm-version";

    public override string Info() =>
        "Syntax: (sys-scm-version)\n" +
        "Library: (scm system)\n" +
        "Description: Returns the SCM interpreter version as a string.\n" +
        "Example:\n" +
        "  (sys-scm-version) => \"0.0.1\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        var version = Assembly.GetExecutingAssembly()
            .GetName().Version?.ToString(3) ?? "unknown";
        return version.ToCharArray();
    }
}
