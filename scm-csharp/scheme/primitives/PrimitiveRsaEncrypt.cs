using System.Security.Cryptography;

namespace scheme;

public class PrimitiveRsaEncrypt : Primitive
{
    public override string Name() => "rsa-encrypt";

    public override string Info() =>
        "Syntax: (rsa-encrypt public-key plaintext)\n" +
        "Library: (scm crypto)\n" +
        "Description: Encrypts plaintext using RSA with OAEP-SHA256 padding. public-key must be a bytevector in SubjectPublicKeyInfo DER format (as returned by rsa-generate-keypair). Returns a bytevector.\n" +
        "Example:\n" +
        "  (rsa-encrypt pub plaintext) => #u8(...)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        byte[] pubKeyDer = Value.AsBytevector(arguments[0]);
        byte[] plaintext = Value.AsBytevector(arguments[1]);
        using var rsa = RSA.Create();
        rsa.ImportSubjectPublicKeyInfo(pubKeyDer, out _);
        return rsa.Encrypt(plaintext, RSAEncryptionPadding.OaepSHA256);
    }
}
