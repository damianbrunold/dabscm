package scheme.primitives;
import scheme.*;

public class PrimitiveHttpResponseP extends Primitive {
    @Override
    public String name() { return "http-response?"; }

    @Override
    public String info() {
        return "Syntax: (http-response? x)\n" +
               "Library: (scm net http response)\n" +
               "Description: Returns #t if x is an HTTP response object.\n" +
               "Example:\n" +
               "  (http-response? (make-http-response 200 '() \"ok\")) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isNativeValue(arguments[0]) && Value.asNativeValue(arguments[0]).value instanceof SchemeHttpResponse
            ? Value.T : Value.F;
    }
}
