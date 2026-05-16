namespace scheme;

public class PrimitiveTerminatedThreadExceptionP : Primitive
{
    public override string Name() => "terminated-thread-exception?";

    public override string Info() =>
        "Syntax: (terminated-thread-exception? obj)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns #t if obj is a terminated-thread exception.\n" +
        "Example:\n" +
        "  (terminated-thread-exception? exn)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return PrimitiveJoinTimeoutExceptionP.IsThreadException(
            arguments[0], ThreadExceptionKind.TERMINATED_THREAD) ? Value.T : Value.F;
    }
}
