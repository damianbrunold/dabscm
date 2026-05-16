package scheme.primitives;

import javax.crypto.Cipher;
import java.security.KeyFactory;
import java.security.GeneralSecurityException;
import java.security.spec.X509EncodedKeySpec;
import javax.crypto.spec.OAEPParameterSpec;
import java.security.spec.MGF1ParameterSpec;
import javax.crypto.spec.PSource;
import scheme.*;

public class PrimitiveRsaEncrypt extends Primitive {
    @Override
    public String name() { return "rsa-encrypt"; }

    @Override
    public String info() {
        return "Syntax: (rsa-encrypt public-key plaintext)\n" +
               "Library: (scm crypto)\n" +
               "Description: Encrypts plaintext using RSA with OAEP-SHA256 padding. public-key must be a bytevector in SubjectPublicKeyInfo DER format (as returned by rsa-generate-keypair). Returns a bytevector.\n" +
               "Example:\n" +
               "  (rsa-encrypt pub plaintext) => #u8(...)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        byte[] pubKeyDer = Value.asBytevector(arguments[0]);
        byte[] plaintext = Value.asBytevector(arguments[1]);
        try {
            KeyFactory kf = KeyFactory.getInstance("RSA");
            var pubKey = kf.generatePublic(new X509EncodedKeySpec(pubKeyDer));
            Cipher cipher = Cipher.getInstance("RSA/ECB/OAEPWithSHA-256AndMGF1Padding");
            cipher.init(Cipher.ENCRYPT_MODE, pubKey,
                new OAEPParameterSpec("SHA-256", "MGF1", MGF1ParameterSpec.SHA256, PSource.PSpecified.DEFAULT));
            return cipher.doFinal(plaintext);
        } catch (GeneralSecurityException e) {
            throw new SchemeError(pos, "rsa-encrypt: " + e.getMessage());
        }
    }
}
