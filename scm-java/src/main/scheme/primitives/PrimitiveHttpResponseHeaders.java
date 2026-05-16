package scheme.primitives;
import scheme.*;

public class PrimitiveHttpResponseHeaders extends Primitive {
    @Override
    public String name() { return "http-response-headers"; }

    @Override
    public String info() {
        return "Syntax: (http-response-headers response)\n" +
               "Library: (scm net http response)\n" +
               "Description: Returns the headers of the HTTP response as an alist of (name . value) pairs.\n" +
               "Example:\n" +
               "  (http-response-headers resp) => ((\"Content-Type\" . \"text/html\"))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeHttpResponse resp = (SchemeHttpResponse) Value.asNativeValue(arguments[0]).value;
        Object result = Value.NIL;
        for (int i = resp.headers.size() - 1; i >= 0; i--) {
            Pair kv = new Pair(resp.headers.get(i)[0].toCharArray(), resp.headers.get(i)[1].toCharArray());
            result = new Pair(kv, result);
        }
        return result;
    }
}
