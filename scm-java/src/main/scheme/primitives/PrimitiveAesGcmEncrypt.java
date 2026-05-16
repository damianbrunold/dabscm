package scheme.primitives;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.GeneralSecurityException;
import scheme.*;

public class PrimitiveAesGcmEncrypt extends Primitive {
    @Override
    public String name() { return "aes-gcm-encrypt"; }

    @Override
    public String info() {
        return "Syntax: (aes-gcm-encrypt key nonce plaintext [aad])\n" +
               "Library: (scm crypto)\n" +
               "Description: Encrypts plaintext using AES-GCM. key must be 16, 24, or 32 bytes; nonce must be 12 bytes. Optional aad is additional authenticated data. Returns ciphertext concatenated with 16-byte authentication tag.\n" +
               "Example:\n" +
               "  (aes-gcm-encrypt key nonce plaintext) => #u8(...)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 4);
        byte[] key = Value.asBytevector(arguments[0]);
        byte[] nonce = Value.asBytevector(arguments[1]);
        byte[] plaintext = Value.asBytevector(arguments[2]);
        byte[] aad = arguments.length > 3 ? Value.asBytevector(arguments[3]) : new byte[0];
        try {
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(key, "AES"), new GCMParameterSpec(128, nonce));
            cipher.updateAAD(aad);
            return cipher.doFinal(plaintext);
        } catch (GeneralSecurityException e) {
            throw new SchemeError(pos, "aes-gcm-encrypt: " + e.getMessage());
        }
    }
}
