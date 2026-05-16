package scheme.primitives;

import javax.crypto.Cipher;
import java.security.KeyFactory;
import java.security.GeneralSecurityException;
import java.security.spec.PKCS8EncodedKeySpec;
import javax.crypto.spec.OAEPParameterSpec;
import java.security.spec.MGF1ParameterSpec;
import javax.crypto.spec.PSource;
import scheme.*;

public class PrimitiveRsaDecrypt extends Primitive {
    @Override
    public String name() { return "rsa-decrypt"; }

    @Override
    public String info() {
        return "Syntax: (rsa-decrypt private-key ciphertext)\n" +
               "Library: (scm crypto)\n" +
               "Description: Decrypts ciphertext using RSA with OAEP-SHA256 padding. private-key must be a bytevector in PKCS#8 DER format (as returned by rsa-generate-keypair). Returns a bytevector.\n" +
               "Example:\n" +
               "  (rsa-decrypt priv ciphertext) => #u8(...)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        byte[] privKeyDer = Value.asBytevector(arguments[0]);
        byte[] ciphertext = Value.asBytevector(arguments[1]);
        try {
            KeyFactory kf = KeyFactory.getInstance("RSA");
            var privKey = kf.generatePrivate(new PKCS8EncodedKeySpec(privKeyDer));
            Cipher cipher = Cipher.getInstance("RSA/ECB/OAEPWithSHA-256AndMGF1Padding");
            cipher.init(Cipher.DECRYPT_MODE, privKey,
                new OAEPParameterSpec("SHA-256", "MGF1", MGF1ParameterSpec.SHA256, PSource.PSpecified.DEFAULT));
            return cipher.doFinal(ciphertext);
        } catch (GeneralSecurityException e) {
            throw new SchemeError(pos, "rsa-decrypt: " + e.getMessage());
        }
    }
}
