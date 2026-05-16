package scheme.primitives;

import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.GeneralSecurityException;
import scheme.*;

public class PrimitiveAesCbcEncrypt extends Primitive {
    @Override
    public String name() { return "aes-cbc-encrypt"; }

    @Override
    public String info() {
        return "Syntax: (aes-cbc-encrypt key iv plaintext)\n" +
               "Library: (scm crypto)\n" +
               "Description: Encrypts plaintext using AES-CBC with PKCS7 padding. key must be 16, 24, or 32 bytes; iv must be 16 bytes. Returns a bytevector.\n" +
               "Example:\n" +
               "  (aes-cbc-encrypt key iv plaintext) => #u8(...)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        byte[] key = Value.asBytevector(arguments[0]);
        byte[] iv = Value.asBytevector(arguments[1]);
        byte[] plaintext = Value.asBytevector(arguments[2]);
        try {
            Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
            cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(key, "AES"), new IvParameterSpec(iv));
            return cipher.doFinal(plaintext);
        } catch (GeneralSecurityException e) {
            throw new SchemeError(pos, "aes-cbc-encrypt: " + e.getMessage());
        }
    }
}
