package scheme.primitives;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import scheme.*;

public class PrimitiveSHA256Hash extends Primitive {
    @Override
    public String name() { return "sha256-hash"; }

    @Override
    public String info() {
        return "Syntax: (sha256-hash obj)\n" +
               "Library: (scm crypto)\n" +
               "Description: Returns the SHA-256 hash of obj as a bytevector. Accepts strings, symbols, or bytevectors.\n" +
               "Example:\n" +
               "  (sha256-hash \"hello\") => #u8(...)";
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
            throw new SchemeError(pos, "sha256-hash: cannot hash value");
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return digest.digest(b);
        } catch (NoSuchAlgorithmException e) {
            throw new SchemeError(pos, "sha256-hash: algorithm not available");
        }
    }
}
