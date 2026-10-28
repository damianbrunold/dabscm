package scheme.primitives;
import scheme.*;

public class PrimitiveHttpResponseWithHeaders extends Primitive {
    @Override
    public String name() { return "http-response-with-headers"; }

    @Override
    public String info() {
        return "Syntax: (http-response-with-headers response status headers)\n" +
               "Library: (scm net http response)\n" +
               "Description: Returns a copy of response with the given status and headers alist and the same body,\n" +
               "  whatever its kind: in memory, a file part (make-http-file-response) or streamed\n" +
               "  (make-http-stream-response). Middleware uses it to add headers without reading the body.\n" +
               "Example:\n" +
               "  (http-response-with-headers resp (http-response-status resp)\n" +
               "    (cons '(\"X-Frame-Options\" . \"DENY\") (http-response-headers resp)))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        SchemeHttpResponse r = (SchemeHttpResponse) Value.asNativeValue(arguments[0]).value;
        SchemeHttpResponse c = new SchemeHttpResponse(IntegerMath.toInt(arguments[1]),
            PrimitiveMakeHttpResponse.parseHeaders(arguments[2]), r.body);
        c.bodyBytes = r.bodyBytes;
        c.filePath = r.filePath;
        c.fileOffset = r.fileOffset;
        c.fileLength = r.fileLength;
        c.writer = r.writer;
        return new NativeValue(c);
    }
}
