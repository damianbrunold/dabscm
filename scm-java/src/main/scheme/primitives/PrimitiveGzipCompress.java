package scheme.primitives;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.zip.GZIPOutputStream;
import java.util.zip.Deflater;
import scheme.*;

public class PrimitiveGzipCompress extends Primitive {
    @Override
    public String name() { return "gzip-compress"; }

    @Override
    public String info() {
        return "Syntax: (gzip-compress bytevector [level])\n" +
               "Library: (scm compression)\n" +
               "Description: Compresses bytevector using GZip format (RFC 1952) and returns\n" +
               "  a bytevector. The optional level is an integer 0-9: 0 = no compression,\n" +
               "  1-3 = fastest, 4-6 = optimal (default), 7-9 = smallest size.\n" +
               "Example:\n" +
               "  (utf8->string (gzip-decompress (gzip-compress (string->utf8 \"hello\")))) => \"hello\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        byte[] input = Value.asBytevector(arguments[0]);
        int level = arguments.length > 1
            ? (int)(long) arguments[1]
            : Deflater.DEFAULT_COMPRESSION;

        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        try {
            GZIPOutputStream gzip = new GZIPOutputStream(buf) {{
                def.setLevel(level);
            }};
            gzip.write(input);
            gzip.close();
        } catch (IOException e) {
            throw new SchemeError(pos, "gzip-compress: ~a", e.getMessage());
        }
        return buf.toByteArray();
    }
}
