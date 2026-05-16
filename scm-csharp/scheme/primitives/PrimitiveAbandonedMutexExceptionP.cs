namespace scheme;

public class PrimitiveAbandonedMutexExceptionP : Primitive
{
    public override string Name() => "abandoned-mutex-exception?";

    public override string Info() =>
        "Syntax: (abandoned-mutex-exception? obj)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns #t if obj is an abandoned-mutex exception.\n" +
        "Example:\n" +
        "  (abandoned-mutex-exception? exn)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return PrimitiveJoinTimeoutExceptionP.IsThreadException(
            arguments[0], ThreadExceptionKind.ABANDONED_MUTEX) ? Value.T : Value.F;
    }
}
