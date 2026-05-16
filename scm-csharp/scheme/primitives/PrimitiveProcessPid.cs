namespace scheme;

public class PrimitiveProcessPid : Primitive
{
    public override string Name() => "process-pid";

    public override string Info() =>
        "Syntax: (process-pid handle)\n" +
        "Library: (scm system)\n" +
        "Description: Returns the OS process id of a process handle returned by " +
        "start-program.\n" +
        "Example:\n" +
        "  (process-pid p) => 12345";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeProcess sp = (SchemeProcess) Value.AsNativeValue(arguments[0]).value;
        return (long) sp.process.Id;
    }
}
