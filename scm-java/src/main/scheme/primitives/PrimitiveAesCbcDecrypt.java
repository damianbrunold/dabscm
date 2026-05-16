package scheme.primitives;

import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.GeneralSecurityException;
import scheme.*;

public class PrimitiveAesCbcDecrypt extends Primitive {
    @Override
    public String name() { return "aes-cbc-decrypt"; }

    @Override
    public String info() {
        return "Syntax: (aes-cbc-decrypt key iv ciphertext)\n" +
               "Library: (scm crypto)\n" +
               "Description: Decrypts ciphertext using AES-CBC with PKCS7 padding. key must be 16, 24, or 32 bytes; iv must be 16 bytes. Returns a bytevector.\n" +
               "Example:\n" +
               "  (aes-cbc-decrypt key iv ciphertext) => #u8(...)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        byte[] key = Value.asBytevector(arguments[0]);
        byte[] iv = Value.asBytevector(arguments[1]);
        byte[] ciphertext = Value.asBytevector(arguments[2]);
        try {
            Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
            cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(key, "AES"), new IvParameterSpec(iv));
            return cipher.doFinal(ciphertext);
        } catch (GeneralSecurityException e) {
            throw new SchemeError(pos, "aes-cbc-decrypt: " + e.getMessage());
        }
    }
}
