package scheme.primitives;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;
import java.security.GeneralSecurityException;
import scheme.*;

public class PrimitiveAesEcbDecrypt extends Primitive {
    @Override
    public String name() { return "aes-ecb-decrypt"; }

    @Override
    public String info() {
        return "Syntax: (aes-ecb-decrypt key ciphertext)\n" +
               "Library: (scm crypto)\n" +
               "Description: Decrypts ciphertext using AES-ECB with PKCS7 padding. key must be 16, 24, or 32 bytes. Returns a bytevector.\n" +
               "Example:\n" +
               "  (aes-ecb-decrypt key ciphertext) => #u8(...)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        byte[] key = Value.asBytevector(arguments[0]);
        byte[] ciphertext = Value.asBytevector(arguments[1]);
        try {
            Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding");
            cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(key, "AES"));
            return cipher.doFinal(ciphertext);
        } catch (GeneralSecurityException e) {
            throw new SchemeError(pos, "aes-ecb-decrypt: " + e.getMessage());
        }
    }
}
