namespace scheme;

public class PrimitiveHttpResponseWithHeaders : Primitive
{
    public override string Name() => "http-response-with-headers";

    public override string Info() =>
        "Syntax: (http-response-with-headers response status headers)\n" +
        "Library: (scm net http response)\n" +
        "Description: Returns a copy of response with the given status and headers alist and the same body,\n" +
        "  whatever its kind: in memory, a file part (make-http-file-response) or streamed\n" +
        "  (make-http-stream-response). Middleware uses it to add headers without reading the body.\n" +
        "Example:\n" +
        "  (http-response-with-headers resp (http-response-status resp)\n" +
        "    (cons '(\"X-Frame-Options\" . \"DENY\") (http-response-headers resp)))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        var r = (SchemeHttpResponse) Value.AsNativeValue(arguments[0]).value;
        var c = new SchemeHttpResponse(IntegerMath.ToInt(arguments[1]),
            PrimitiveMakeHttpResponse.ParseHeaders(arguments[2]), r.Body);
        c.BodyBytes = r.BodyBytes;
        c.FilePath = r.FilePath;
        c.FileOffset = r.FileOffset;
        c.FileLength = r.FileLength;
        c.Writer = r.Writer;
        c.WebSocket = r.WebSocket;
        return new NativeValue(c);
    }
}
