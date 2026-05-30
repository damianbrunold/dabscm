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
               "Library: (scheme file)\n" +
               "Description: Takes a filename and returns a textual input port that reads characters from the named file. It is an error if the file cannot be opened.\n" +
               "Example:\n" +
               "  (define p (open-input-file \"data.txt\"))\n" +
               "  (read-char p) => first character of file";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        String filename = new String(Value.asString(arguments[0]));
        if (!Files.exists(LongPath.of(filename))) {
            throw new SchemeError(pos, new FileErrorObject("open-input-file: file not found", new Object[] { filename }));
        }
        try {
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
                    if (pbstrm.read(bom) != -1) {
                        if (!(bom[0] == (byte) 0xEF && bom[1] == (byte) 0xBB && bom[2] == (byte) 0xBF)) {
                            pbstrm.unread(bom);
                        }
                    }
                    return new TextStream(new PushbackReader(new BufferedReader(new InputStreamReader(pbstrm, encoding), 8192)), filename);
                } else {
                    return new TextStream(new PushbackReader(new BufferedReader(new InputStreamReader(strm, encoding), 8192)), filename);
                }
            }
        } catch (Exception e) {
            throw new SchemeError(pos, new FileErrorObject("open-input-file: io error", new Object[] { filename }));
        }
    }
}
