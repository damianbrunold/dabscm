package scheme.primitives;

import java.io.ByteArrayOutputStream;
import java.util.zip.Deflater;
import scheme.*;

public class PrimitiveZlibCompress extends Primitive {
    @Override
    public String name() { return "zlib-compress"; }

    @Override
    public String info() {
        return "Syntax: (zlib-compress bytevector [level])\n" +
               "Library: (scm compression)\n" +
               "Description: Compresses bytevector using ZLib framing (RFC 1950) and returns\n" +
               "  a bytevector. The optional level is an integer 0-9: 0 = no compression,\n" +
               "  1-3 = fastest, 4-6 = optimal (default), 7-9 = smallest size.\n" +
               "Example:\n" +
               "  (utf8->string (zlib-decompress (zlib-compress (string->utf8 \"hello\")))) => \"hello\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        byte[] input = Value.asBytevector(arguments[0]);
        int level = arguments.length > 1
            ? (int)(long) arguments[1]
            : Deflater.DEFAULT_COMPRESSION;

        Deflater deflater = new Deflater(level, false); // nowrap=false for ZLib framing
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
