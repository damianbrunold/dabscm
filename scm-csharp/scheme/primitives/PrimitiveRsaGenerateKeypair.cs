using System.Security.Cryptography;

namespace scheme;

public class PrimitiveRsaGenerateKeypair : Primitive
{
    public override string Name() => "rsa-generate-keypair";

    public override string Info() =>
        "Syntax: (rsa-generate-keypair bits)\n" +
        "Library: (scm crypto)\n" +
        "Description: Generates an RSA key pair of the given bit size (e.g. 2048, 4096). Returns a list of two bytevectors: (list public-key private-key). The public key is in SubjectPublicKeyInfo DER format; the private key is in PKCS#8 DER format.\n" +
        "Example:\n" +
        "  (define kp (rsa-generate-keypair 2048))\n" +
        "  (define pub (car kp))\n" +
        "  (define priv (cadr kp))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        int bits = IntegerMath.ToInt(arguments[0]);
        using var rsa = RSA.Create(bits);
        byte[] pub = rsa.ExportSubjectPublicKeyInfo();
        byte[] priv = rsa.ExportPkcs8PrivateKey();
        return Pair.List(pub, priv);
    }
}
