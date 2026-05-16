using System.Security.Cryptography;

namespace scheme;

public class PrimitiveHMACSHA256 : Primitive
{
    public override string Name() => "hmac-sha256";

    public override string Info() =>
        "Syntax: (hmac-sha256 key data)\n" +
        "Library: (scm crypto)\n" +
        "Description: Computes HMAC-SHA256 of data using key. Both key and data must be bytevectors. Returns a bytevector.\n" +
        "Example:\n" +
        "  (hmac-sha256 key-bv data-bv) => #u8(...)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        byte[] key = Value.AsBytevector(arguments[0]);
        byte[] data = Value.AsBytevector(arguments[1]);
        using var hmac = new HMACSHA256(key);
        return hmac.ComputeHash(data);
    }
}
