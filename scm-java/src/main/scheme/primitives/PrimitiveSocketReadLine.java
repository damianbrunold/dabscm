package scheme.primitives;

import scheme.*;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

public class PrimitiveSocketReadLine extends Primitive {
    @Override
    public String name() { return "socket-read-line"; }

    @Override
    public String info() {
        return "Syntax: (socket-read-line socket)\n" +
               "Library: (scm net sockets)\n" +
               "Description: Reads one line directly from the socket's raw underlying stream, byte\n" +
               "  by byte with no buffering, decoding the bytes as UTF-8. A trailing CR is dropped\n" +
               "  and the line is terminated by LF; the returned string does not include the line\n" +
               "  ending. Returns an end-of-file object if the stream is closed before any byte is\n" +
               "  read. Because it never buffers ahead, it is safe for line-oriented protocols (such\n" +
               "  as SMTP) where a buffered reader would consume bytes past a protocol boundary like\n" +
               "  a STARTTLS upgrade.\n" +
               "Example:\n" +
               "  (socket-read-line sock) => \"220 mail.example.com ESMTP\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeSocket ss = (SchemeSocket) Value.asNativeValue(arguments[0]).value;
        try {
            InputStream in = ss.networkInputStream;
            ByteArrayOutputStream bytes = new ByteArrayOutputStream();
            boolean any = false;
            int b;
            while ((b = in.read()) != -1) {
                any = true;
                if (b == '\n') break;
                if (b == '\r') continue;
                bytes.write(b);
            }
            if (!any) return Value.EOF;
            return new String(bytes.toByteArray(), StandardCharsets.UTF_8).toCharArray();
        } catch (Exception e) {
            throw new SchemeError(pos, "socket-read-line: io failure: ~a", e.getMessage());
        }
    }
}
