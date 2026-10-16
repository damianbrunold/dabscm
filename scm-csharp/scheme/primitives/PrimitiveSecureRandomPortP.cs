namespace scheme;

public class PrimitiveSecureRandomPortP : Primitive
{
    public override string Name() => "secure-random-port?";
    public override string Info() =>
        "Syntax: (secure-random-port? obj)\n" +
        "Library: (srfi 271 randomized)\n" +
        "Description: Returns #t if obj is a port made by make-secure-random-port.\n" +
        "Example:\n" +
        "  (secure-random-port? (make-secure-random-port)) => #t";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return arguments[0] is BinaryInputStream port && port.Source is SecureRandomInputStream;
    }
}
