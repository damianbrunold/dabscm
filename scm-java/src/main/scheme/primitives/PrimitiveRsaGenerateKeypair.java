package scheme.primitives;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.NoSuchAlgorithmException;
import scheme.*;

public class PrimitiveRsaGenerateKeypair extends Primitive {
    @Override
    public String name() { return "rsa-generate-keypair"; }

    @Override
    public String info() {
        return "Syntax: (rsa-generate-keypair bits)\n" +
               "Library: (scm crypto)\n" +
               "Description: Generates an RSA key pair of the given bit size (e.g. 2048, 4096). Returns a list of two bytevectors: (list public-key private-key). The public key is in SubjectPublicKeyInfo DER format; the private key is in PKCS#8 DER format.\n" +
               "Example:\n" +
               "  (define kp (rsa-generate-keypair 2048))\n" +
               "  (define pub (car kp))\n" +
               "  (define priv (cadr kp))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        int bits = IntegerMath.toInt(arguments[0]);
        try {
            KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA");
            kpg.initialize(bits);
            KeyPair kp = kpg.generateKeyPair();
            byte[] pub = kp.getPublic().getEncoded();
            byte[] priv = kp.getPrivate().getEncoded();
            return Pair.list(pub, priv);
        } catch (NoSuchAlgorithmException e) {
            throw new SchemeError(pos, "rsa-generate-keypair: " + e.getMessage());
        }
    }
}
