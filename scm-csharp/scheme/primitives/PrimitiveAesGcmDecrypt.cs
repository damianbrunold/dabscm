using System.Security.Cryptography;

namespace scheme;

public class PrimitiveAesGcmDecrypt : Primitive
{
    public override string Name() => "aes-gcm-decrypt";

    public override string Info() =>
        "Syntax: (aes-gcm-decrypt key nonce ciphertext [aad])\n" +
        "Library: (scm crypto)\n" +
        "Description: Decrypts ciphertext using AES-GCM. key must be 16, 24, or 32 bytes; nonce must be 12 bytes. The ciphertext argument must include the 16-byte authentication tag appended at the end. Raises an error if authentication fails.\n" +
        "Example:\n" +
        "  (aes-gcm-decrypt key nonce ciphertext-with-tag) => #u8(...)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 4);
        byte[] key = Value.AsBytevector(arguments[0]);
        byte[] nonce = Value.AsBytevector(arguments[1]);
        byte[] input = Value.AsBytevector(arguments[2]);
        byte[] aad = arguments.Length > 3 ? Value.AsBytevector(arguments[3]) : Array.Empty<byte>();
        if (input.Length < 16)
            throw new SchemeError(pos, "aes-gcm-decrypt: input too short to contain authentication tag");
        int ctLen = input.Length - 16;
        byte[] ciphertext = new byte[ctLen];
        byte[] tag = new byte[16];
        Buffer.BlockCopy(input, 0, ciphertext, 0, ctLen);
        Buffer.BlockCopy(input, ctLen, tag, 0, 16);
        byte[] plaintext = new byte[ctLen];
        using var gcm = new AesGcm(key, tagSizeInBytes: 16);
        try
        {
            gcm.Decrypt(nonce, ciphertext, tag, plaintext, aad.Length > 0 ? aad : null);
        }
        catch (AuthenticationTagMismatchException)
        {
            throw new SchemeError(pos, "aes-gcm-decrypt: authentication tag mismatch");
        }
        return plaintext;
    }
}
