package scheme.primitives;
import scheme.*;
import java.util.ArrayList;
import java.util.List;

public class PrimitiveMakeHttpRequest extends Primitive {
    @Override
    public String name() { return "make-http-request"; }

    @Override
    public String info() {
        return "Syntax: (make-http-request method url headers body) (make-http-request method url headers body timeout-seconds)\n" +
               "Library: (scm net http request)\n" +
               "Description: Creates an HTTP request object. headers is an alist of (name . value) pairs. body is a string or #f.\n" +
               "  Optional timeout-seconds overrides the default request timeout (600s); <= 0 means no timeout.\n" +
               "Example:\n" +
               "  (make-http-request \"GET\" \"/\" '() #f)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 4, 5);
        String method = new String(Value.asString(arguments[0]));
        String url = new String(Value.asString(arguments[1]));
        List<String[]> headers = new ArrayList<>();
        Object hlist = arguments[2];
        while (hlist != Value.NIL) {
            Pair hp = (Pair) hlist;
            Pair kv = (Pair) hp.car;
            String key = new String(Value.asString(kv.car));
            String val = new String(Value.asString(kv.cdr));
            headers.add(new String[]{key, val});
            hlist = hp.cdr;
        }
        String body = arguments[3] == Value.F ? null : new String(Value.asString(arguments[3]));
        SchemeHttpRequest req = new SchemeHttpRequest(method, url, headers, body);
        if (arguments.length == 5) {
            req.timeoutSeconds = Value.asInteger(arguments[4]).intValue();
        }
        return new NativeValue(req);
    }
}
