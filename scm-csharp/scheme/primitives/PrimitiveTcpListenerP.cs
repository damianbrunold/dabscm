namespace scheme;

public class PrimitiveTcpListenerP : Primitive
{
    public override string Name() => "tcp-listener?";

    public override string Info() =>
        "Syntax: (tcp-listener? x)\n" +
        "Library: (scm net sockets)\n" +
        "Description: Returns #t if x is a TCP listener.\n" +
        "Example:\n" +
        "  (tcp-listener? (tcp-listen 8080)) => #t";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsNativeValue(arguments[0]) && Value.AsNativeValue(arguments[0]).value is SchemeListener
            ? Value.T : Value.F;
    }
}
