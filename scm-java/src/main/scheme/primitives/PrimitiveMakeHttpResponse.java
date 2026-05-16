package scheme.primitives;
import scheme.*;
import java.util.ArrayList;
import java.util.List;

public class PrimitiveMakeHttpResponse extends Primitive {
    @Override
    public String name() { return "make-http-response"; }

    @Override
    public String info() {
        return "Syntax: (make-http-response status headers body)\n" +
               "Library: (scm net http response)\n" +
               "Description: Creates an HTTP response object. status is an integer, headers is an alist, body is a string or bytevector.\n" +
               "Example:\n" +
               "  (make-http-response 200 '() \"OK\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        int status = IntegerMath.toInt(arguments[0]);
        List<String[]> headers = new ArrayList<>();
        Object hlist = arguments[1];
        while (hlist != Value.NIL) {
            Pair hp = (Pair) hlist;
            Pair kv = (Pair) hp.car;
            String key = new String(Value.asString(kv.car));
            String val = new String(Value.asString(kv.cdr));
            headers.add(new String[]{key, val});
            hlist = hp.cdr;
        }
        if (Value.isBytevector(arguments[2])) {
            byte[] bytes = Value.asBytevector(arguments[2]);
            return new NativeValue(new SchemeHttpResponse(status, headers, bytes));
        }
        String body = new String(Value.asString(arguments[2]));
        return new NativeValue(new SchemeHttpResponse(status, headers, body));
    }
}
