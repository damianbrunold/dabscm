package scheme.primitives;

import java.util.zip.CRC32;
import scheme.*;

public class PrimitiveCrc32 extends Primitive {
    @Override
    public String name() { return "crc32"; }

    @Override
    public String info() {
        return "Syntax: (crc32 bytevector [start [end]])\n" +
               "Library: (scm png)\n" +
               "Description: Computes the IEEE CRC-32 checksum (polynomial 0xEDB88320,\n" +
               "  as used by PNG, gzip, zip) of bytevector and returns it as an exact\n" +
               "  non-negative integer in [0, 2^32).\n" +
               "Example:\n" +
               "  (crc32 (string->utf8 \"123456789\")) => 3421780262";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        byte[] input = Value.asBytevector(arguments[0]);
        int start = arguments.length > 1 ? (int)(long) arguments[1] : 0;
        int end = arguments.length > 2 ? (int)(long) arguments[2] : input.length;
        CRC32 crc = new CRC32();
        crc.update(input, start, end - start);
        return crc.getValue();
    }
}
