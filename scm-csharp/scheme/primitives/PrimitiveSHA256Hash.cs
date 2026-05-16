using System.Text;
using System.Security.Cryptography;

namespace scheme;

public class PrimitiveSHA256Hash : Primitive
{
    public override string Name() => "sha256-hash";

    public override string Info() =>
        "Syntax: (sha256-hash obj)\n" +
        "Library: (scm crypto)\n" +
        "Description: Returns the SHA-256 hash of obj as a bytevector. Accepts strings, symbols, or bytevectors.\n" +
        "Example:\n" +
        "  (sha256-hash \"hello\") => #u8(...)";

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
            throw new SchemeError(pos, "sha256-hash: cannot hash value");
        return SHA256.HashData(b);
    }
}
