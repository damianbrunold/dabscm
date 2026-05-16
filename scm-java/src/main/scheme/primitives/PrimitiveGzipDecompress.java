package scheme.primitives;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.zip.GZIPInputStream;
import scheme.*;

public class PrimitiveGzipDecompress extends Primitive {
    @Override
    public String name() { return "gzip-decompress"; }

    @Override
    public String info() {
        return "Syntax: (gzip-decompress bytevector)\n" +
               "Library: (scm compression)\n" +
               "Description: Decompresses a GZip-compressed (RFC 1952) bytevector and returns\n" +
               "  the original bytevector.\n" +
               "Example:\n" +
               "  (utf8->string (gzip-decompress (gzip-compress (string->utf8 \"hello\")))) => \"hello\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        byte[] input = Value.asBytevector(arguments[0]);

        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        try {
            GZIPInputStream gzip = new GZIPInputStream(new ByteArrayInputStream(input));
            byte[] tmp = new byte[4096];
            int n;
            while ((n = gzip.read(tmp)) != -1)
                buf.write(tmp, 0, n);
            gzip.close();
        } catch (IOException e) {
            throw new SchemeError(pos, "gzip-decompress: ~a", e.getMessage());
        }
        return buf.toByteArray();
    }
}
