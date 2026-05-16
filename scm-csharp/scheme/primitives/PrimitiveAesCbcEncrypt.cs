using System.Security.Cryptography;

namespace scheme;

public class PrimitiveAesCbcEncrypt : Primitive
{
    public override string Name() => "aes-cbc-encrypt";

    public override string Info() =>
        "Syntax: (aes-cbc-encrypt key iv plaintext)\n" +
        "Library: (scm crypto)\n" +
        "Description: Encrypts plaintext using AES-CBC with PKCS7 padding. key must be 16, 24, or 32 bytes; iv must be 16 bytes. Returns a bytevector.\n" +
        "Example:\n" +
        "  (aes-cbc-encrypt key iv plaintext) => #u8(...)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        byte[] key = Value.AsBytevector(arguments[0]);
        byte[] iv = Value.AsBytevector(arguments[1]);
        byte[] plaintext = Value.AsBytevector(arguments[2]);
        using var aes = Aes.Create();
        aes.Mode = CipherMode.CBC;
        aes.Padding = PaddingMode.PKCS7;
        aes.Key = key;
        aes.IV = iv;
        using var encryptor = aes.CreateEncryptor();
        return encryptor.TransformFinalBlock(plaintext, 0, plaintext.Length);
    }
}
