package scheme.primitives;

import scheme.*;

public class PrimitiveMakeChaCha20Port extends Primitive {
    @Override public String name() { return "make-chacha20-port"; }
    @Override public String info() {
        return "Syntax: (make-chacha20-port key counter offset)\n" +
               "Library: (srfi 271 determinized)\n" +
               "Description: Returns a binary input port delivering the endless ChaCha20\n" +
               "  keystream for the 32-byte bytevector key (all-zero nonce), starting at\n" +
               "  byte offset (0..63) of block counter (0..2^63-1).\n" +
               "Example:\n" +
               "  (read-u8 (make-chacha20-port (make-bytevector 32 0) 0 0)) => 118";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        if (!Value.isBytevector(arguments[0]) || Value.asBytevector(arguments[0]).length != 32)
            throw new SchemeError(pos, "make-chacha20-port: key must be a bytevector of length 32");
        if (!Value.isFixnum(arguments[1]) || Value.asInteger(arguments[1]) < 0)
            throw new SchemeError(pos, "make-chacha20-port: counter must be an exact integer in 0..2^63-1");
        if (!Value.isFixnum(arguments[2])
                || Value.asInteger(arguments[2]) < 0 || Value.asInteger(arguments[2]) > 63)
            throw new SchemeError(pos, "make-chacha20-port: offset must be an exact integer in 0..63");
        var stream = new ChaCha20InputStream(Value.asBytevector(arguments[0]),
                                             Value.asInteger(arguments[1]),
                                             (int) (long) Value.asInteger(arguments[2]));
        return new BinaryInputStream(stream, false);
    }
}
