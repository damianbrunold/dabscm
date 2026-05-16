namespace scheme;

public class PrimitiveUncaughtExceptionReason : Primitive
{
    public override string Name() => "uncaught-exception-reason";

    public override string Info() =>
        "Syntax: (uncaught-exception-reason exn)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns the original exception from an uncaught-exception object.\n" +
        "Example:\n" +
        "  (uncaught-exception-reason exn)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var te = PrimitiveJoinTimeoutExceptionP.GetThreadException(arguments[0]);
        if (te != null && te.kind == ThreadExceptionKind.UNCAUGHT)
            return te.reason ?? Value.NIL;
        throw new SchemeError(pos, "uncaught-exception-reason: expected uncaught exception, got ~s", arguments[0]);
    }
}
