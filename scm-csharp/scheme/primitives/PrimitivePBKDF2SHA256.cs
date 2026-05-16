using System.Text;
using System.Security.Cryptography;

namespace scheme;

public class PrimitivePBKDF2SHA256 : Primitive
{
    public override string Name() => "pbkdf2-sha256";

    public override string Info() =>
        "Syntax: (pbkdf2-sha256 password salt iterations length)\n" +
        "Library: (scm crypto)\n" +
        "Description: Derives a key using PBKDF2-HMAC-SHA256. Password is a string or bytevector, salt is a bytevector. Returns a bytevector of given length.\n" +
        "Example:\n" +
        "  (pbkdf2-sha256 \"password\" salt-bv 4096 32) => #u8(...)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 4, 4);
        byte[] password;
        if (Value.IsString(arguments[0]))
            password = Encoding.UTF8.GetBytes(Value.AsString(arguments[0]));
        else
            password = Value.AsBytevector(arguments[0]);
        byte[] salt = Value.AsBytevector(arguments[1]);
        int iterations = IntegerMath.ToInt(arguments[2]);
        int length = IntegerMath.ToInt(arguments[3]);
        using var pbkdf2 = new Rfc2898DeriveBytes(password, salt, iterations, HashAlgorithmName.SHA256);
        return pbkdf2.GetBytes(length);
    }
}
