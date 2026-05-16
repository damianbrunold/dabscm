package scheme.primitives;
import scheme.*;

public class PrimitiveHttpRequestMethod extends Primitive {
    @Override
    public String name() { return "http-request-method"; }

    @Override
    public String info() {
        return "Syntax: (http-request-method request)\n" +
               "Library: (scm net http request)\n" +
               "Description: Returns the HTTP method of the request as a string.\n" +
               "Example:\n" +
               "  (http-request-method req) => \"GET\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeHttpRequest req = (SchemeHttpRequest) Value.asNativeValue(arguments[0]).value;
        return req.method.toCharArray();
    }
}
