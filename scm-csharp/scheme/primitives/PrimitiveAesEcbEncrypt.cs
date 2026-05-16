using System.Security.Cryptography;

namespace scheme;

public class PrimitiveAesEcbEncrypt : Primitive
{
    public override string Name() => "aes-ecb-encrypt";

    public override string Info() =>
        "Syntax: (aes-ecb-encrypt key plaintext)\n" +
        "Library: (scm crypto)\n" +
        "Description: Encrypts plaintext using AES-ECB with PKCS7 padding. key must be 16, 24, or 32 bytes. Note: ECB mode is not semantically secure; prefer AES-CBC or AES-GCM. Returns a bytevector.\n" +
        "Example:\n" +
        "  (aes-ecb-encrypt key plaintext) => #u8(...)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        byte[] key = Value.AsBytevector(arguments[0]);
        byte[] plaintext = Value.AsBytevector(arguments[1]);
        using var aes = Aes.Create();
        aes.Mode = CipherMode.ECB;
        aes.Padding = PaddingMode.PKCS7;
        aes.Key = key;
        using var encryptor = aes.CreateEncryptor();
        return encryptor.TransformFinalBlock(plaintext, 0, plaintext.Length);
    }
}
