using System.Security.Cryptography;

namespace scheme;

public class PrimitiveAesEcbDecrypt : Primitive
{
    public override string Name() => "aes-ecb-decrypt";

    public override string Info() =>
        "Syntax: (aes-ecb-decrypt key ciphertext)\n" +
        "Library: (scm crypto)\n" +
        "Description: Decrypts ciphertext using AES-ECB with PKCS7 padding. key must be 16, 24, or 32 bytes. Returns a bytevector.\n" +
        "Example:\n" +
        "  (aes-ecb-decrypt key ciphertext) => #u8(...)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        byte[] key = Value.AsBytevector(arguments[0]);
        byte[] ciphertext = Value.AsBytevector(arguments[1]);
        using var aes = Aes.Create();
        aes.Mode = CipherMode.ECB;
        aes.Padding = PaddingMode.PKCS7;
        aes.Key = key;
        using var decryptor = aes.CreateDecryptor();
        return decryptor.TransformFinalBlock(ciphertext, 0, ciphertext.Length);
    }
}
