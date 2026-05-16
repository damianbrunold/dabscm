package scheme.primitives;

import javax.crypto.AEADBadTagException;
import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.GeneralSecurityException;
import scheme.*;

public class PrimitiveChaCha20Poly1305Decrypt extends Primitive {
    @Override
    public String name() { return "chacha20poly1305-decrypt"; }

    @Override
    public String info() {
        return "Syntax: (chacha20poly1305-decrypt key nonce ciphertext [aad])\n" +
               "Library: (scm crypto)\n" +
               "Description: Decrypts ciphertext using ChaCha20-Poly1305. key must be 32 bytes; nonce must be 12 bytes. The ciphertext argument must include the 16-byte authentication tag appended at the end. Raises an error if authentication fails.\n" +
               "Example:\n" +
               "  (chacha20poly1305-decrypt key nonce ciphertext-with-tag) => #u8(...)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 4);
        byte[] key = Value.asBytevector(arguments[0]);
        byte[] nonce = Value.asBytevector(arguments[1]);
        byte[] input = Value.asBytevector(arguments[2]);
        byte[] aad = arguments.length > 3 ? Value.asBytevector(arguments[3]) : new byte[0];
        try {
            Cipher cipher = Cipher.getInstance("ChaCha20-Poly1305");
            cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(key, "ChaCha20"), new IvParameterSpec(nonce));
            cipher.updateAAD(aad);
            return cipher.doFinal(input);
        } catch (AEADBadTagException e) {
            throw new SchemeError(pos, "chacha20poly1305-decrypt: authentication tag mismatch");
        } catch (GeneralSecurityException e) {
            throw new SchemeError(pos, "chacha20poly1305-decrypt: " + e.getMessage());
        }
    }
}
