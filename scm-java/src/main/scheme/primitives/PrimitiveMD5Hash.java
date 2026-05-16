package scheme.primitives;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import scheme.*;

public class PrimitiveMD5Hash extends Primitive {
    @Override
    public String name() { return "md5-hash"; }

    @Override
    public String info() {
        return "Syntax: (md5-hash obj)\n" +
               "Library: (scm crypto)\n" +
               "Description: Returns the MD5 hash of obj as a lowercase hex string. Accepts strings, symbols, or bytevectors.\n" +
               "Example:\n" +
               "  (md5-hash \"hello\") => \"5d41402abc4b2a76b9719d911017c592\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        byte[] b;
        if (Value.isString(arguments[0]))
            b = new String(Value.asString(arguments[0])).getBytes(StandardCharsets.UTF_8);
        else if (Value.isSymbol(arguments[0]))
            b = Value.asSymbol(arguments[0]).getBytes(StandardCharsets.UTF_8);
        else if (Value.isBytevector(arguments[0]))
            b = Value.asBytevector(arguments[0]);
        else
            throw new SchemeError(pos, "md5-hash: cannot hash value");
        try {
            MessageDigest digest = MessageDigest.getInstance("MD5");
            byte[] data = digest.digest(b);
            StringBuilder result = new StringBuilder();
            for (byte d : data) result.append(String.format("%02x", d));
            return result.toString().toCharArray();
        } catch (NoSuchAlgorithmException e) {
            throw new SchemeError(pos, "md5-hash: algorithm not available");
        }
    }
}
