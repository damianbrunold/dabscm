package scheme.primitives;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;
import scheme.*;

public class PrimitiveHMACSHA256 extends Primitive {
    @Override
    public String name() { return "hmac-sha256"; }

    @Override
    public String info() {
        return "Syntax: (hmac-sha256 key data)\n" +
               "Library: (scm crypto)\n" +
               "Description: Computes HMAC-SHA256 of data using key. Both key and data must be bytevectors. Returns a bytevector.\n" +
               "Example:\n" +
               "  (hmac-sha256 key-bv data-bv) => #u8(...)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        byte[] key = Value.asBytevector(arguments[0]);
        byte[] data = Value.asBytevector(arguments[1]);
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key, "HmacSHA256"));
            return mac.doFinal(data);
        } catch (NoSuchAlgorithmException | InvalidKeyException e) {
            throw new SchemeError(pos, "hmac-sha256: " + e.getMessage());
        }
    }
}
