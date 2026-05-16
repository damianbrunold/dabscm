using System.Security.Cryptography;

namespace scheme;

public class PrimitiveAesCbcDecrypt : Primitive
{
    public override string Name() => "aes-cbc-decrypt";

    public override string Info() =>
        "Syntax: (aes-cbc-decrypt key iv ciphertext)\n" +
        "Library: (scm crypto)\n" +
        "Description: Decrypts ciphertext using AES-CBC with PKCS7 padding. key must be 16, 24, or 32 bytes; iv must be 16 bytes. Returns a bytevector.\n" +
        "Example:\n" +
        "  (aes-cbc-decrypt key iv ciphertext) => #u8(...)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        byte[] key = Value.AsBytevector(arguments[0]);
        byte[] iv = Value.AsBytevector(arguments[1]);
        byte[] ciphertext = Value.AsBytevector(arguments[2]);
        using var aes = Aes.Create();
        aes.Mode = CipherMode.CBC;
        aes.Padding = PaddingMode.PKCS7;
        aes.Key = key;
        aes.IV = iv;
        using var decryptor = aes.CreateDecryptor();
        return decryptor.TransformFinalBlock(ciphertext, 0, ciphertext.Length);
    }
}
