package scheme.primitives;

import java.security.SecureRandom;
import scheme.*;

public class PrimitiveRandomBytes extends Primitive {
    private static final SecureRandom random = new SecureRandom();

    @Override
    public String name() { return "random-bytes"; }

    @Override
    public String info() {
        return "Syntax: (random-bytes n)\n" +
               "Library: (scm crypto)\n" +
               "Description: Returns a fresh bytevector of n cryptographically random bytes.\n" +
               "Example:\n" +
               "  (random-bytes 16) => #u8(...)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        int n = IntegerMath.toInt(arguments[0]);
        byte[] buf = new byte[n];
        random.nextBytes(buf);
        return buf;
    }
}
