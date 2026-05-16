namespace scheme;

public class PrimitiveUncaughtExceptionP : Primitive
{
    public override string Name() => "uncaught-exception?";

    public override string Info() =>
        "Syntax: (uncaught-exception? obj)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns #t if obj is an uncaught exception.\n" +
        "Example:\n" +
        "  (guard (e ((uncaught-exception? e) (uncaught-exception-reason e)))\n" +
        "    (thread-join! (thread-start! (make-thread (lambda () (error \"oops\"))))))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return PrimitiveJoinTimeoutExceptionP.IsThreadException(
            arguments[0], ThreadExceptionKind.UNCAUGHT) ? Value.T : Value.F;
    }
}
