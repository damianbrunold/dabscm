package scheme.primitives;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;

public class PrimitiveSHA1Hash extends Primitive {
    @Override
    public String name() {
        return "sha1-hash";
    }

    @Override
    public String info() {
        return "Syntax: (sha1-hash obj)\n" +
               "Library: (scm crypto)\n" +
               "Description: Returns the SHA-1 hash of obj as a lowercase hex string. Accepts strings, symbols, or bytevectors.\n" +
               "Example:\n" +
               "  (sha1-hash \"hello\") => \"aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        byte[] b = null;
        if (Value.isString(arguments[0])) {
            b = new String(Value.asString(arguments[0])).getBytes(StandardCharsets.UTF_8);
        } else if (Value.isSymbol(arguments[0])) {
            b = Value.asSymbol(arguments[0]).getBytes(StandardCharsets.UTF_8);
        } else if (Value.isBytevector(arguments[0])) {
            b = Value.asBytevector(arguments[0]);
        } else if (arguments[0] != null) {
            var s = arguments[0].toString();
            b = s.getBytes(StandardCharsets.UTF_8);
        } else {
            throw new SchemeError(pos, "sha1-hash: Cannot make sha1-hash from value");
        }
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-1");
            byte[] data = digest.digest(b);
            StringBuilder result = new StringBuilder();
            for (int i = 0; i < data.length; i++) {
                result.append(String.format("%02x", data[i]));
            }
            return result.toString().toCharArray();
        } catch (NoSuchAlgorithmException e) {
            throw new SchemeError(pos, "sha1-hash: Cannot make sha1-hash from value");
        }
    }
}
