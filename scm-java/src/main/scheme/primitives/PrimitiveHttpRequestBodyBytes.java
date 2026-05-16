package scheme.primitives;
import scheme.*;

public class PrimitiveHttpRequestBodyBytes extends Primitive {
    @Override
    public String name() { return "http-request-body-bytes"; }

    @Override
    public String info() {
        return "Syntax: (http-request-body-bytes request)\n" +
               "Library: (scm net http request)\n" +
               "Description: Returns the body of the HTTP request as a bytevector, or #f if there is no body. " +
               "Unlike http-request-body which decodes the body as UTF-8 text, this preserves the raw bytes " +
               "and is the correct accessor for binary uploads.\n" +
               "Example:\n" +
               "  (http-request-body-bytes req) => #u8(72 101 108 108 111)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeHttpRequest req = (SchemeHttpRequest) Value.asNativeValue(arguments[0]).value;
        return req.bodyBytes == null ? Value.F : req.bodyBytes;
    }
}
