package scheme.primitives;
import scheme.*;

public class PrimitiveHttpResponseStatus extends Primitive {
    @Override
    public String name() { return "http-response-status"; }

    @Override
    public String info() {
        return "Syntax: (http-response-status response)\n" +
               "Library: (scm net http response)\n" +
               "Description: Returns the HTTP status code of the response as an integer.\n" +
               "Example:\n" +
               "  (http-response-status resp) => 200";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeHttpResponse resp = (SchemeHttpResponse) Value.asNativeValue(arguments[0]).value;
        return (long) resp.status;
    }
}
