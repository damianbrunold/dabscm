using System.Diagnostics;

namespace scheme;

public class PrimitiveCurrentPid : Primitive
{
    public override string Name() => "current-pid";

    public override string Info() =>
        "Syntax: (current-pid)\n" +
        "Library: (scm system)\n" +
        "Description: Returns the OS process id of the current Scheme process.\n" +
        "Example:\n" +
        "  (current-pid) => 12345";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        return (long) Process.GetCurrentProcess().Id;
    }
}
