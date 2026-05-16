using System.Security.Cryptography;

namespace scheme;

public class PrimitiveAesGcmEncrypt : Primitive
{
    public override string Name() => "aes-gcm-encrypt";

    public override string Info() =>
        "Syntax: (aes-gcm-encrypt key nonce plaintext [aad])\n" +
        "Library: (scm crypto)\n" +
        "Description: Encrypts plaintext using AES-GCM. key must be 16, 24, or 32 bytes; nonce must be 12 bytes. Optional aad is additional authenticated data. Returns ciphertext concatenated with 16-byte authentication tag.\n" +
        "Example:\n" +
        "  (aes-gcm-encrypt key nonce plaintext) => #u8(...)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 4);
        byte[] key = Value.AsBytevector(arguments[0]);
        byte[] nonce = Value.AsBytevector(arguments[1]);
        byte[] plaintext = Value.AsBytevector(arguments[2]);
        byte[] aad = arguments.Length > 3 ? Value.AsBytevector(arguments[3]) : Array.Empty<byte>();
        byte[] ciphertext = new byte[plaintext.Length];
        byte[] tag = new byte[16];
        using var gcm = new AesGcm(key, tagSizeInBytes: 16);
        gcm.Encrypt(nonce, plaintext, ciphertext, tag, aad.Length > 0 ? aad : null);
        byte[] result = new byte[ciphertext.Length + 16];
        Buffer.BlockCopy(ciphertext, 0, result, 0, ciphertext.Length);
        Buffer.BlockCopy(tag, 0, result, ciphertext.Length, 16);
        return result;
    }
}
