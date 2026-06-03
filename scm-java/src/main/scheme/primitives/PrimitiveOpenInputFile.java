package scheme.primitives;

import scheme.*;

import java.io.*;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.zip.Inflater;
import java.util.zip.InflaterInputStream;

public class PrimitiveOpenInputFile extends Primitive {
    @Override
    public String name() {
        return "open-input-file";
    }

    @Override
    public String info() {
        return "Syntax: (open-input-file filename)\n" +
               "        (open-input-file filename option ...)\n" +
               "Library: (scheme file)\n" +
               "Description: Takes a filename and returns a textual input port that reads characters from the named file. It is an error if the file cannot be opened.\n" +
               "  As a non-standard extension, up to two optional arguments may follow the filename. They are symbols (strings are also accepted):\n" +
               "    - an encoding name selects the character encoding (default 'utf-8; also 'latin-1 / 'iso-8859-1, 'utf-16, 'utf-16-le)\n" +
               "    - 'deflate decompresses a DEFLATE-compressed file while reading (as written by open-output-file ... 'deflate)\n" +
               "Example:\n" +
               "  (define p (open-input-file \"data.txt\"))\n" +
               "  (read-char p) => first character of file\n" +
               "  (open-input-file \"legacy.txt\" 'latin-1)  ; decode as Latin-1\n" +
               "  (open-input-file \"data.z\" 'deflate)      ; read compressed input";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        String filename = new String(Value.asString(arguments[0]));
        try {
            // LongPath.of can throw InvalidPathException for names the
            // filesystem rejects (e.g. trailing spaces on Windows); treat
            // those as an unopenable file rather than a generic error.
            if (!Files.exists(LongPath.of(filename))) {
                throw new SchemeError(pos, new FileErrorObject("open-input-file: file not found", new Object[] { filename }));
            }
            Charset encoding = StandardCharsets.UTF_8;
            boolean deflate = false;
            for (var i = 1; i < arguments.length; i++) {
                String arg;
                if (Value.isSymbol(arguments[i])) {
                    arg = Value.asSymbol(arguments[i]);
                } else {
                    arg = new String(Value.asString(arguments[i]));
                }
                if (Encoding.isEncoding(arg)) {
                    encoding = Encoding.getEncoding(arg);
                } else if (arg.equals("deflate")) {
                    deflate = true;
                }
            }
            InputStream strm = Files.newInputStream(LongPath.of(filename));
            if (deflate) {
                return new TextStream(new PushbackReader(new BufferedReader(new InputStreamReader(new InflaterInputStream(strm, new Inflater(true)), encoding), 8192)), filename);
            } else {
                if (encoding.equals(StandardCharsets.UTF_8)) {
                    // check for BOM!
                    var pbstrm = new PushbackInputStream(strm, 3);
                    byte[] bom = new byte[3];
                    int n = pbstrm.read(bom);
                    if (n > 0) {
                        boolean isBom = n >= 3
                            && bom[0] == (byte) 0xEF
                            && bom[1] == (byte) 0xBB
                            && bom[2] == (byte) 0xBF;
                        // Only push back the bytes actually read; unreading the
                        // full array would inject garbage for files < 3 bytes.
                        if (!isBom) {
                            pbstrm.unread(bom, 0, n);
                        }
                    }
                    return new TextStream(new PushbackReader(new BufferedReader(new InputStreamReader(pbstrm, encoding), 8192)), filename);
                } else {
                    return new TextStream(new PushbackReader(new BufferedReader(new InputStreamReader(strm, encoding), 8192)), filename);
                }
            }
        } catch (SchemeError e) {
            throw e;
        } catch (Exception e) {
            throw new SchemeError(pos, new FileErrorObject("open-input-file: io error", new Object[] { filename }));
        }
    }
}
