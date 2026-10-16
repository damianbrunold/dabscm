namespace scheme;

public class PrimitiveChaCha20PortP : Primitive
{
    public override string Name() => "chacha20-port?";
    public override string Info() =>
        "Syntax: (chacha20-port? obj)\n" +
        "Library: (srfi 271 determinized)\n" +
        "Description: Returns #t if obj is a port made by make-chacha20-port.\n" +
        "Example:\n" +
        "  (chacha20-port? (make-chacha20-port (make-bytevector 32 1) 0 0)) => #t";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return arguments[0] is BinaryInputStream port && port.Source is ChaCha20InputStream;
    }
}
