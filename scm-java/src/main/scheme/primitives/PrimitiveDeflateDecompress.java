package scheme.primitives;

import java.io.ByteArrayOutputStream;
import java.util.zip.Inflater;
import java.util.zip.DataFormatException;
import scheme.*;

public class PrimitiveDeflateDecompress extends Primitive {
    @Override
    public String name() { return "deflate-decompress"; }

    @Override
    public String info() {
        return "Syntax: (deflate-decompress bytevector)\n" +
               "Library: (scm compression)\n" +
               "Description: Decompresses a raw DEFLATE-compressed (RFC 1951) bytevector\n" +
               "  and returns the original bytevector.\n" +
               "Example:\n" +
               "  (utf8->string (deflate-decompress (deflate-compress (string->utf8 \"hello\")))) => \"hello\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        byte[] input = Value.asBytevector(arguments[0]);

        Inflater inflater = new Inflater(true); // nowrap=true for raw DEFLATE
        inflater.setInput(input);
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        byte[] tmp = new byte[4096];
        try {
            while (!inflater.finished()) {
                int n = inflater.inflate(tmp);
                if (n == 0 && inflater.needsInput()) break;
                buf.write(tmp, 0, n);
            }
        } catch (DataFormatException e) {
            throw new SchemeError(pos, "deflate-decompress: ~a", e.getMessage());
        } finally {
            inflater.end();
        }
        return buf.toByteArray();
    }
}
