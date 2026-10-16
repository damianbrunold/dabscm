namespace scheme;

public class PrimitiveMakeSecureRandomPort : Primitive
{
    public override string Name() => "make-secure-random-port";
    public override string Info() =>
        "Syntax: (make-secure-random-port)\n" +
        "Library: (srfi 271 randomized)\n" +
        "Description: Returns a binary input port delivering an endless stream of\n" +
        "  cryptographically random bytes. It never returns an eof object.\n" +
        "Example:\n" +
        "  (bytevector-length (read-bytevector 16 (make-secure-random-port))) => 16";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        return new BinaryInputStream(new SecureRandomInputStream());
    }
}
