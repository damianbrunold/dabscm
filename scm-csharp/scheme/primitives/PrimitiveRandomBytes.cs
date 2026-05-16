using System.Security.Cryptography;

namespace scheme;

public class PrimitiveRandomBytes : Primitive
{
    public override string Name() => "random-bytes";

    public override string Info() =>
        "Syntax: (random-bytes n)\n" +
        "Library: (scm crypto)\n" +
        "Description: Returns a fresh bytevector of n cryptographically random bytes.\n" +
        "Example:\n" +
        "  (random-bytes 16) => #u8(...)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        int n = IntegerMath.ToInt(arguments[0]);
        return RandomNumberGenerator.GetBytes(n);
    }
}
