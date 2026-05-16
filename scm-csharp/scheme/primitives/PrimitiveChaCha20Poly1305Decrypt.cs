using System.Security.Cryptography;

namespace scheme;

public class PrimitiveChaCha20Poly1305Decrypt : Primitive
{
    public override string Name() => "chacha20poly1305-decrypt";

    public override string Info() =>
        "Syntax: (chacha20poly1305-decrypt key nonce ciphertext [aad])\n" +
        "Library: (scm crypto)\n" +
        "Description: Decrypts ciphertext using ChaCha20-Poly1305. key must be 32 bytes; nonce must be 12 bytes. The ciphertext argument must include the 16-byte authentication tag appended at the end. Raises an error if authentication fails.\n" +
        "Example:\n" +
        "  (chacha20poly1305-decrypt key nonce ciphertext-with-tag) => #u8(...)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 4);
        byte[] key = Value.AsBytevector(arguments[0]);
        byte[] nonce = Value.AsBytevector(arguments[1]);
        byte[] input = Value.AsBytevector(arguments[2]);
        byte[] aad = arguments.Length > 3 ? Value.AsBytevector(arguments[3]) : Array.Empty<byte>();
        if (input.Length < 16)
            throw new SchemeError(pos, "chacha20poly1305-decrypt: input too short to contain authentication tag");
        int ctLen = input.Length - 16;
        byte[] ciphertext = new byte[ctLen];
        byte[] tag = new byte[16];
        Buffer.BlockCopy(input, 0, ciphertext, 0, ctLen);
        Buffer.BlockCopy(input, ctLen, tag, 0, 16);
        byte[] plaintext = new byte[ctLen];
        using var cipher = new ChaCha20Poly1305(key);
        try
        {
            cipher.Decrypt(nonce, ciphertext, tag, plaintext, aad.Length > 0 ? aad : null);
        }
        catch (AuthenticationTagMismatchException)
        {
            throw new SchemeError(pos, "chacha20poly1305-decrypt: authentication tag mismatch");
        }
        return plaintext;
    }
}
