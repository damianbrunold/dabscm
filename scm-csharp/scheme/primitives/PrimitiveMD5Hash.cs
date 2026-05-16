using System.Text;
using System.Security.Cryptography;

namespace scheme;

public class PrimitiveMD5Hash : Primitive
{
    public override string Name() => "md5-hash";

    public override string Info() =>
        "Syntax: (md5-hash obj)\n" +
        "Library: (scm crypto)\n" +
        "Description: Returns the MD5 hash of obj as a lowercase hex string. Accepts strings, symbols, or bytevectors.\n" +
        "Example:\n" +
        "  (md5-hash \"hello\") => \"5d41402abc4b2a76b9719d911017c592\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        byte[] b;
        if (Value.IsString(arguments[0]))
            b = Encoding.UTF8.GetBytes(Value.AsString(arguments[0]));
        else if (Value.IsSymbol(arguments[0]))
            b = Encoding.UTF8.GetBytes(Value.AsSymbol(arguments[0]));
        else if (Value.IsBytevector(arguments[0]))
            b = Value.AsBytevector(arguments[0]);
        else
            throw new SchemeError(pos, "md5-hash: cannot hash value");
        return Convert.ToHexString(MD5.HashData(b)).ToLower().ToCharArray();
    }
}
