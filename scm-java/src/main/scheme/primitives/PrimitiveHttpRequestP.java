package scheme.primitives;
import scheme.*;

public class PrimitiveHttpRequestP extends Primitive {
    @Override
    public String name() { return "http-request?"; }

    @Override
    public String info() {
        return "Syntax: (http-request? x)\n" +
               "Library: (scm net http request)\n" +
               "Description: Returns #t if x is an HTTP request object.\n" +
               "Example:\n" +
               "  (http-request? (make-http-request \"GET\" \"/\" '() #f)) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isNativeValue(arguments[0]) && Value.asNativeValue(arguments[0]).value instanceof SchemeHttpRequest
            ? Value.T : Value.F;
    }
}
