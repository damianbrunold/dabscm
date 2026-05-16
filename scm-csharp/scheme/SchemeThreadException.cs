namespace scheme;

public enum ThreadExceptionKind { JOIN_TIMEOUT, ABANDONED_MUTEX, TERMINATED_THREAD, UNCAUGHT }

public class SchemeThreadException
{
    public ThreadExceptionKind kind;
    public object? reason;

    public SchemeThreadException(ThreadExceptionKind kind, object? reason = null)
    {
        this.kind = kind;
        this.reason = reason;
    }

    public override string ToString() => kind switch
    {
        ThreadExceptionKind.JOIN_TIMEOUT => "#<join-timeout-exception>",
        ThreadExceptionKind.ABANDONED_MUTEX => "#<abandoned-mutex-exception>",
        ThreadExceptionKind.TERMINATED_THREAD => "#<terminated-thread-exception>",
        ThreadExceptionKind.UNCAUGHT => "#<uncaught-exception>",
        _ => "#<thread-exception>"
    };
}
