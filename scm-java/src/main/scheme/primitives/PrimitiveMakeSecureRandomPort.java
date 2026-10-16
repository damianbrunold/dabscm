package scheme.primitives;

import scheme.*;

public class PrimitiveMakeSecureRandomPort extends Primitive {
    @Override public String name() { return "make-secure-random-port"; }
    @Override public String info() {
        return "Syntax: (make-secure-random-port)\n" +
               "Library: (srfi 271 randomized)\n" +
               "Description: Returns a binary input port delivering an endless stream of\n" +
               "  cryptographically random bytes. It never returns an eof object.\n" +
               "Example:\n" +
               "  (bytevector-length (read-bytevector 16 (make-secure-random-port))) => 16";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return new BinaryInputStream(new SecureRandomInputStream());
    }
}
