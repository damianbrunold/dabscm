namespace scheme;

public class PrimitiveSocketP : Primitive
{
    public override string Name() => "socket?";

    public override string Info() =>
        "Syntax: (socket? x)\n" +
        "Library: (scm net sockets)\n" +
        "Description: Returns #t if x is a TCP socket.\n" +
        "Example:\n" +
        "  (socket? (tcp-connect \"localhost\" 8080)) => #t";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsNativeValue(arguments[0]) && Value.AsNativeValue(arguments[0]).value is SchemeSocket
            ? Value.T : Value.F;
    }
}
