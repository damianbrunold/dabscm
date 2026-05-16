package scheme.primitives;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;
import java.security.GeneralSecurityException;
import scheme.*;

public class PrimitiveAesEcbEncrypt extends Primitive {
    @Override
    public String name() { return "aes-ecb-encrypt"; }

    @Override
    public String info() {
        return "Syntax: (aes-ecb-encrypt key plaintext)\n" +
               "Library: (scm crypto)\n" +
               "Description: Encrypts plaintext using AES-ECB with PKCS7 padding. key must be 16, 24, or 32 bytes. Note: ECB mode is not semantically secure; prefer AES-CBC or AES-GCM. Returns a bytevector.\n" +
               "Example:\n" +
               "  (aes-ecb-encrypt key plaintext) => #u8(...)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        byte[] key = Value.asBytevector(arguments[0]);
        byte[] plaintext = Value.asBytevector(arguments[1]);
        try {
            Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding");
            cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(key, "AES"));
            return cipher.doFinal(plaintext);
        } catch (GeneralSecurityException e) {
            throw new SchemeError(pos, "aes-ecb-encrypt: " + e.getMessage());
        }
    }
}
