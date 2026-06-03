package scheme.primitives;

import scheme.*;

import java.io.*;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.StandardOpenOption;
import java.util.zip.Deflater;
import java.util.zip.DeflaterOutputStream;

public class PrimitiveOpenOutputFile extends Primitive {
    @Override
    public String name() {
        return "open-output-file";
    }

    @Override
    public String info() {
        return "Syntax: (open-output-file filename)\n" +
               "        (open-output-file filename option ...)\n" +
               "Library: (scheme file)\n" +
               "Description: Takes a filename and returns a textual output port that writes characters to the named file. The file is created or truncated. It is an error if the file cannot be opened.\n" +
               "  As a non-standard extension, up to three optional arguments may follow the filename. They are symbols (strings are also accepted):\n" +
               "    - an encoding name selects the character encoding (default 'utf-8; also 'utf-8-bom, 'latin-1 / 'iso-8859-1, 'utf-16, 'utf-16-le)\n" +
               "    - 'deflate writes a DEFLATE-compressed stream (read it back with open-input-file ... 'deflate)\n" +
               "    - 'append appends to the file instead of truncating it\n" +
               "Example:\n" +
               "  (define p (open-output-file \"out.txt\"))\n" +
               "  (write-char #\\A p)\n" +
               "  (open-output-file \"log.txt\" 'append 'latin-1)  ; append, Latin-1\n" +
               "  (open-output-file \"data.z\" 'deflate)           ; compressed output";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 4);
        String filename = new String(Value.asString(arguments[0]));
        try {
            Charset encoding = StandardCharsets.UTF_8;
            boolean append = false;
            boolean deflate = false;
            @SuppressWarnings("unused")
            boolean add_bom = false;
            for (var i = 1; i < arguments.length; i++) {
                String arg;
                if (Value.isSymbol(arguments[i])) {
                    arg = Value.asSymbol(arguments[i]);
                } else {
                    arg = new String(Value.asString(arguments[i]));
                }
                if (Encoding.isEncoding(arg)) {
                    encoding = Encoding.getEncoding(arg);
                    add_bom = arg.toLowerCase().equals("utf8bom")
                        || arg.toLowerCase().equals("utf-8-bom");
                } else if (arg.equals("deflate")) {
                    deflate = true;
                } else if (arg.equals("append")) {
                    append = true;
                }
            }
            OutputStream fos = append
                ? Files.newOutputStream(LongPath.of(filename), StandardOpenOption.CREATE, StandardOpenOption.APPEND)
                : Files.newOutputStream(LongPath.of(filename), StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
            if (deflate) {
                return new TextOutputStream(new BufferedWriter(new OutputStreamWriter(new DeflaterOutputStream(fos, new Deflater(Deflater.DEFAULT_COMPRESSION, true)), encoding), 8192));
            } else {
                // TODO handle BOM?
                return new TextOutputStream(new BufferedWriter(new OutputStreamWriter(fos, encoding), 8192));
            }
        } catch (Exception e) {
            throw new SchemeError(pos, new FileErrorObject("open-output-file: io failure", new Object[] { filename }));
        }
    }
}
