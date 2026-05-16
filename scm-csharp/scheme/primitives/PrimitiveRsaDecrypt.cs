using System.Security.Cryptography;

namespace scheme;

public class PrimitiveRsaDecrypt : Primitive
{
    public override string Name() => "rsa-decrypt";

    public override string Info() =>
        "Syntax: (rsa-decrypt private-key ciphertext)\n" +
        "Library: (scm crypto)\n" +
        "Description: Decrypts ciphertext using RSA with OAEP-SHA256 padding. private-key must be a bytevector in PKCS#8 DER format (as returned by rsa-generate-keypair). Returns a bytevector.\n" +
        "Example:\n" +
        "  (rsa-decrypt priv ciphertext) => #u8(...)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        byte[] privKeyDer = Value.AsBytevector(arguments[0]);
        byte[] ciphertext = Value.AsBytevector(arguments[1]);
        using var rsa = RSA.Create();
        rsa.ImportPkcs8PrivateKey(privKeyDer, out _);
        return rsa.Decrypt(ciphertext, RSAEncryptionPadding.OaepSHA256);
    }
}
