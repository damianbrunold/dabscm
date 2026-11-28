namespace scheme;

public class PrimitiveHttpRequestBodyBytes : Primitive
{
    public override string Name() => "http-request-body-bytes";

    public override string Info() =>
        "Syntax: (http-request-body-bytes request)\n" +
        "Library: (scm net http request)\n" +
        "Description: Returns the body of the HTTP request as a bytevector, or #f if there is no body. " +
        "Unlike http-request-body which decodes the body as UTF-8 text, this preserves the raw bytes " +
        "and is the correct accessor for binary uploads. A request made by make-http-request with a " +
        "string body gives that string's UTF-8 bytes.\n" +
        "Example:\n" +
        "  (http-request-body-bytes req) => #u8(72 101 108 108 111)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeHttpRequest req = (SchemeHttpRequest) Value.AsNativeValue(arguments[0]).value;
        byte[]? bytes = req.GetBodyBytes();
        // a request made with a string body: its UTF-8 bytes
        if (bytes == null && req.GetBody() != null)
            bytes = System.Text.Encoding.UTF8.GetBytes(req.GetBody()!);
        return bytes == null ? Value.F : (object) bytes;
    }
}
