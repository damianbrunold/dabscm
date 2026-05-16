package scheme.primitives;
import scheme.*;

public class PrimitiveHttpRequestUrl extends Primitive {
    @Override
    public String name() { return "http-request-url"; }

    @Override
    public String info() {
        return "Syntax: (http-request-url request)\n" +
               "Library: (scm net http request)\n" +
               "Description: Returns the URL of the HTTP request as a string.\n" +
               "Example:\n" +
               "  (http-request-url req) => \"/api/users\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeHttpRequest req = (SchemeHttpRequest) Value.asNativeValue(arguments[0]).value;
        return req.url.toCharArray();
    }
}
