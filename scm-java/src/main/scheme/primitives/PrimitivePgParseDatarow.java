package scheme.primitives;

import scheme.*;

import java.nio.charset.StandardCharsets;

public class PrimitivePgParseDatarow extends Primitive {
    @Override public String name() { return "pg-parse-datarow"; }
    @Override public String info() {
        return "Syntax: (pg-parse-datarow body)\n" +
               "Library: (scm core)\n" +
               "Description: Parses a PostgreSQL DataRow message body bytevector " +
               "and returns a vector with one element per column. Each element is " +
               "a UTF-8 decoded string, an empty string for zero-length values, or " +
               "#f for NULL. body must point at the column-count int16; the 5-byte " +
               "type+length frame must already be stripped.\n" +
               "Example:\n" +
               "  (pg-parse-datarow body) => #(\"1\" \"alice\" #f)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        try {
            byte[] body = Value.asBytevector(arguments[0]);
            int off = 0;
            int ncols = ((body[off] & 0xFF) << 8) | (body[off + 1] & 0xFF);
            off += 2;
            Object[] result = new Object[ncols];
            for (int i = 0; i < ncols; i++) {
                int len = ((body[off]     & 0xFF) << 24)
                        | ((body[off + 1] & 0xFF) << 16)
                        | ((body[off + 2] & 0xFF) << 8)
                        |  (body[off + 3] & 0xFF);
                off += 4;
                if (len == -1) {
                    result[i] = Boolean.FALSE;
                } else if (len == 0) {
                    result[i] = new char[0];
                } else {
                    String s = new String(body, off, len, StandardCharsets.UTF_8);
                    result[i] = s.toCharArray();
                    off += len;
                }
            }
            return result;
        } catch (Exception e) {
            throw new SchemeError(pos, "pg-parse-datarow: parse failure: ~a", e.getMessage());
        }
    }
}
