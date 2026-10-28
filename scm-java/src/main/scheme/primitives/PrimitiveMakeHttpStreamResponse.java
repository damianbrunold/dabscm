package scheme.primitives;
import scheme.*;

public class PrimitiveMakeHttpStreamResponse extends Primitive {
    @Override
    public String name() { return "make-http-stream-response"; }

    @Override
    public String info() {
        return "Syntax: (make-http-stream-response status headers writer)\n" +
               "Library: (scm net http response)\n" +
               "Description: Creates an HTTP response whose body tcp-http-serve produces by calling (writer port)\n" +
               "  with a binary output port to the client, after sending the status and headers. The body ends\n" +
               "  when writer returns (the connection then closes), so there is no Content-Length; call\n" +
               "  flush-output-port to send what was written so far (server-sent events, progress). Writing\n" +
               "  raises an error once the client has gone.\n" +
               "Example:\n" +
               "  (make-http-stream-response 200 '((\"Content-Type\" . \"text/event-stream\"))\n" +
               "    (lambda (port)\n" +
               "      (write-bytevector (string->utf8 \"data: hello\\n\\n\") port)\n" +
               "      (flush-output-port port)))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        int status = IntegerMath.toInt(arguments[0]);
        return new NativeValue(SchemeHttpResponse.ofWriter(
            status, PrimitiveMakeHttpResponse.parseHeaders(arguments[1]), Value.asLambda(arguments[2])));
    }
}
