package scheme.primitives;
import scheme.*;

public class PrimitiveHttpRequestBodyFile extends Primitive {
    @Override
    public String name() { return "http-request-body-file"; }

    @Override
    public String info() {
        return "Syntax: (http-request-body-file request)\n" +
               "Library: (scm net http request)\n" +
               "Description: Returns the path of the temporary file holding the request's body, or #f. tcp-http-serve\n" +
               "  writes a body larger than its spool threshold to such a file instead of keeping it in memory, and\n" +
               "  deletes the file once the response is sent: move it (move-file) to keep it. http-request-body and\n" +
               "  http-request-body-bytes still work, reading the file into memory.\n" +
               "Example:\n" +
               "  (let ((f (http-request-body-file req)))\n" +
               "    (if f (move-file f dest) (write-bytes-to dest (http-request-body-bytes req))))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeHttpRequest req = (SchemeHttpRequest) Value.asNativeValue(arguments[0]).value;
        return req.bodyFile == null ? Value.F : req.bodyFile.toString().toCharArray();
    }
}
