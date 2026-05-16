package scheme.primitives;
import scheme.*;

public class PrimitiveHttpRequestHeaders extends Primitive {
    @Override
    public String name() { return "http-request-headers"; }

    @Override
    public String info() {
        return "Syntax: (http-request-headers request)\n" +
               "Library: (scm net http request)\n" +
               "Description: Returns the headers of the HTTP request as an alist of (name . value) pairs.\n" +
               "Example:\n" +
               "  (http-request-headers req) => ((\"Host\" . \"example.com\"))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeHttpRequest req = (SchemeHttpRequest) Value.asNativeValue(arguments[0]).value;
        Object result = Value.NIL;
        for (int i = req.headers.size() - 1; i >= 0; i--) {
            Pair kv = new Pair(req.headers.get(i)[0].toCharArray(), req.headers.get(i)[1].toCharArray());
            result = new Pair(kv, result);
        }
        return result;
    }
}
