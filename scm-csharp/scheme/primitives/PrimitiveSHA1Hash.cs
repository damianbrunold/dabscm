using System.Text;
using System.Security.Cryptography;

namespace scheme;

public class PrimitiveSHA1Hash : Primitive
{
    public override string Name()
    {
        return "sha1-hash";
    }

    public override string Info()
    {
        return
            "Syntax: (sha1-hash obj)\n" +
            "Library: (scm crypto)\n" +
            "Description: Returns the SHA-1 hash of obj as a lowercase hex string. Accepts strings, symbols, or bytevectors.\n" +
            "Example:\n" +
            "  (sha1-hash \"hello\") => \"aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsString(arguments[0]))
        {
            var b = Encoding.UTF8.GetBytes(Value.AsString(arguments[0]));
            return Convert.ToHexString(SHA1.HashData(b)).ToLower().ToCharArray();
        }
        else if (Value.IsSymbol(arguments[0]))
        {
            var b = Encoding.UTF8.GetBytes(Value.AsSymbol(arguments[0]));
            return Convert.ToHexString(SHA1.HashData(b)).ToLower().ToCharArray();
        }
        else if (Value.IsBytevector(arguments[0]))
        {
            var b = Value.AsBytevector(arguments[0]);
            return Convert.ToHexString(SHA1.HashData(b)).ToLower().ToCharArray();
        }
        else if (arguments[0] != null)
        {
            var s = arguments[0].ToString();
            var b = Encoding.UTF8.GetBytes(s!);
            return Convert.ToHexString(SHA1.HashData(b)).ToLower().ToCharArray();
        }
        else
        {
            throw new SchemeError(pos, "sha1-hash: Cannot make sha1-hash from value");
        }
    }
}
