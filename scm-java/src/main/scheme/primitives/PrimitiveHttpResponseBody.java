package scheme.primitives;
import scheme.*;

public class PrimitiveHttpResponseBody extends Primitive {
    @Override
    public String name() { return "http-response-body"; }

    @Override
    public String info() {
        return "Syntax: (http-response-body response)\n" +
               "Library: (scm net http response)\n" +
               "Description: Returns the body of the HTTP response. If the response was created with a bytevector body, returns a bytevector; otherwise returns a string.\n" +
               "Example:\n" +
               "  (http-response-body resp) => \"Hello, world!\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeHttpResponse resp = (SchemeHttpResponse) Value.asNativeValue(arguments[0]).value;
        if (resp.bodyBytes != null) return resp.bodyBytes;
        return resp.body.toCharArray();
    }
}
