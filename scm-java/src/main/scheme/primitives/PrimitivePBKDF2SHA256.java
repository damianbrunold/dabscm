package scheme.primitives;

import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.NoSuchAlgorithmException;
import java.security.spec.InvalidKeySpecException;
import scheme.*;

public class PrimitivePBKDF2SHA256 extends Primitive {
    @Override
    public String name() { return "pbkdf2-sha256"; }

    @Override
    public String info() {
        return "Syntax: (pbkdf2-sha256 password salt iterations length)\n" +
               "Library: (scm crypto)\n" +
               "Description: Derives a key using PBKDF2-HMAC-SHA256. Password is a string or bytevector, salt is a bytevector. Returns a bytevector of given length.\n" +
               "Example:\n" +
               "  (pbkdf2-sha256 \"password\" salt-bv 4096 32) => #u8(...)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 4, 4);
        char[] password;
        if (Value.isString(arguments[0]))
            password = Value.asString(arguments[0]);
        else {
            byte[] bv = Value.asBytevector(arguments[0]);
            password = new String(bv, StandardCharsets.UTF_8).toCharArray();
        }
        byte[] salt = Value.asBytevector(arguments[1]);
        int iterations = IntegerMath.toInt(arguments[2]);
        int length = IntegerMath.toInt(arguments[3]);
        try {
            PBEKeySpec spec = new PBEKeySpec(password, salt, iterations, length * 8);
            SecretKeyFactory factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256");
            return factory.generateSecret(spec).getEncoded();
        } catch (NoSuchAlgorithmException | InvalidKeySpecException e) {
            throw new SchemeError(pos, "pbkdf2-sha256: " + e.getMessage());
        }
    }
}
