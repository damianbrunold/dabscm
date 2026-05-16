package scheme.primitives;

import java.io.ByteArrayOutputStream;
import java.util.zip.Deflater;
import scheme.*;

public class PrimitiveDeflateCompress extends Primitive {
    @Override
    public String name() { return "deflate-compress"; }

    @Override
    public String info() {
        return "Syntax: (deflate-compress bytevector [level])\n" +
               "Library: (scm compression)\n" +
               "Description: Compresses bytevector using raw DEFLATE (RFC 1951) and returns\n" +
               "  a bytevector. The optional level is an integer 0-9: 0 = no compression,\n" +
               "  1-3 = fastest, 4-6 = optimal (default), 7-9 = smallest size.\n" +
               "Example:\n" +
               "  (utf8->string (deflate-decompress (deflate-compress (string->utf8 \"hello\")))) => \"hello\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        byte[] input = Value.asBytevector(arguments[0]);
        int level = arguments.length > 1
            ? (int)(long) arguments[1]
            : Deflater.DEFAULT_COMPRESSION;

        Deflater deflater = new Deflater(level, true); // nowrap=true for raw DEFLATE
        deflater.setInput(input);
        deflater.finish();
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        byte[] tmp = new byte[4096];
        while (!deflater.finished()) {
            int n = deflater.deflate(tmp);
            buf.write(tmp, 0, n);
        }
        deflater.end();
        return buf.toByteArray();
    }
}
