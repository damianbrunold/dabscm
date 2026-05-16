package scheme.primitives;
import scheme.*;

public class PrimitiveHttpRequestBody extends Primitive {
    @Override
    public String name() { return "http-request-body"; }

    @Override
    public String info() {
        return "Syntax: (http-request-body request)\n" +
               "Library: (scm net http request)\n" +
               "Description: Returns the body of the HTTP request as a string, or #f if there is no body.\n" +
               "Example:\n" +
               "  (http-request-body req) => \"hello\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeHttpRequest req = (SchemeHttpRequest) Value.asNativeValue(arguments[0]).value;
        return req.body == null ? Value.F : req.body.toCharArray();
    }
}
