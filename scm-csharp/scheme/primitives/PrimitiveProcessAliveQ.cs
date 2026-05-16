namespace scheme;

public class PrimitiveProcessAliveQ : Primitive
{
    public override string Name() => "process-alive?";

    public override string Info() =>
        "Syntax: (process-alive? handle)\n" +
        "Library: (scm system)\n" +
        "Description: Returns #t if the process started by start-program is still " +
        "running, #f if it has exited.\n" +
        "Example:\n" +
        "  (process-alive? p) => #t";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeProcess sp = (SchemeProcess) Value.AsNativeValue(arguments[0]).value;
        return sp.process.HasExited ? Value.F : Value.T;
    }
}
