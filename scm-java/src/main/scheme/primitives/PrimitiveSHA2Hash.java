package scheme.primitives;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import scheme.*;

/** sha224-hash, sha384-hash and sha512-hash (sha256-hash has its own class). */
public class PrimitiveSHA2Hash extends Primitive {
    private final String name;
    private final String algorithm;

    public PrimitiveSHA2Hash(String name, String algorithm) {
        this.name = name;
        this.algorithm = algorithm;
    }

    @Override
    public String name() { return name; }

    @Override
    public String info() {
        return "Syntax: (" + name + " obj)\n" +
               "Library: (scm crypto)\n" +
               "Description: Returns the " + algorithm + " hash of obj as a bytevector. Accepts strings\n" +
               "  (hashed as UTF-8), symbols, or bytevectors.\n" +
               "Example:\n" +
               "  (bytevector->hex (" + name + " \"abc\")) => \"...\"";
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
            throw new SchemeError(pos, name + ": cannot hash value");
        try {
            return MessageDigest.getInstance(algorithm).digest(b);
        } catch (NoSuchAlgorithmException e) {
            throw new SchemeError(pos, name + ": algorithm not available");
        }
    }
}
