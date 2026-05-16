using System;

namespace scheme;

public class PrimitiveServerWait : Primitive
{
    public override string Name() => "server-wait";

    public override string Info() =>
        "Syntax: (server-wait server)\n" +
        "Library: (scm net http server)\n" +
        "Description: Blocks the calling thread until the given HTTP server has stopped. " +
        "Returns when the server's accept loop has exited, e.g. after server-stop.\n" +
        "Example:\n" +
        "  (server-wait s)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeServer s = (SchemeServer) Value.AsNativeValue(arguments[0]).value;
        try { s.task.Wait(); } catch (AggregateException) { } catch (OperationCanceledException) { }
        return Value.T;
    }
}
