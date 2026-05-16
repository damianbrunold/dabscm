namespace scheme;

public class PrimitiveJoinTimeoutExceptionP : Primitive
{
    public override string Name() => "join-timeout-exception?";

    public override string Info() =>
        "Syntax: (join-timeout-exception? obj)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns #t if obj is a join-timeout exception.\n" +
        "Example:\n" +
        "  (guard (e ((join-timeout-exception? e) 'timeout)) (thread-join! t 0))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return IsThreadException(arguments[0], ThreadExceptionKind.JOIN_TIMEOUT) ? Value.T : Value.F;
    }

    internal static bool IsThreadException(object obj, ThreadExceptionKind kind)
    {
        if (obj is ErrorObject eo && eo.Irritants.Length > 0
            && eo.Irritants[0] is NativeValue nv && nv.value is SchemeThreadException te)
            return te.kind == kind;
        if (obj is NativeValue nv2 && nv2.value is SchemeThreadException te2)
            return te2.kind == kind;
        return false;
    }

    internal static SchemeThreadException? GetThreadException(object obj)
    {
        if (obj is ErrorObject eo && eo.Irritants.Length > 0
            && eo.Irritants[0] is NativeValue nv && nv.value is SchemeThreadException te)
            return te;
        if (obj is NativeValue nv2 && nv2.value is SchemeThreadException te2)
            return te2;
        return null;
    }
}
