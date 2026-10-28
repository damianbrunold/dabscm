package scheme.primitives;
import scheme.*;

public class PrimitiveHttpResponseBody extends Primitive {
    @Override
    public String name() { return "http-response-body"; }

    @Override
    public String info() {
        return "Syntax: (http-response-body response)\n" +
               "Library: (scm net http response)\n" +
               "Description: Returns the body of the HTTP response: a bytevector if the response was created with one, or received\n" +
               "  with a body that is not text (see http-get), or is a file response (its part of the file); otherwise a\n" +
               "  string. A streamed response (make-http-stream-response) has no body to return: an error.\n" +
               "Example:\n" +
               "  (http-response-body resp) => \"Hello, world!\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeHttpResponse resp = (SchemeHttpResponse) Value.asNativeValue(arguments[0]).value;
        if (resp.filePath != null || resp.writer != null) return resp.getBodyBytes();
        if (resp.bodyBytes != null) return resp.bodyBytes;
        return resp.body.toCharArray();
    }
}
