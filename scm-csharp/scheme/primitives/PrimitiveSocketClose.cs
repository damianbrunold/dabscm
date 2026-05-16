namespace scheme;

public class PrimitiveSocketClose : Primitive
{
    public override string Name() => "socket-close";

    public override string Info() =>
        "Syntax: (socket-close socket-or-listener)\n" +
        "Library: (scm net sockets)\n" +
        "Description: Closes a socket or TCP listener.\n" +
        "Example:\n" +
        "  (socket-close sock)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (!Value.IsNativeValue(arguments[0]))
            throw new SchemeError(pos, "socket-close: expected socket or listener");
        var nv = Value.AsNativeValue(arguments[0]);
        if (nv.value is SchemeSocket ss)
            ss.client.Close();
        else if (nv.value is SchemeListener sl)
            sl.listener.Stop();
        else
            throw new SchemeError(pos, "socket-close: expected socket or listener");
        return Value.T;
    }
}
