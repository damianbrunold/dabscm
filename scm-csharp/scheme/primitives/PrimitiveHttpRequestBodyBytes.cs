namespace scheme;

public class PrimitiveHttpRequestBodyBytes : Primitive
{
    public override string Name() => "http-request-body-bytes";

    public override string Info() =>
        "Syntax: (http-request-body-bytes request)\n" +
        "Library: (scm net http request)\n" +
        "Description: Returns the body of the HTTP request as a bytevector, or #f if there is no body. " +
        "Unlike http-request-body which decodes the body as UTF-8 text, this preserves the raw bytes " +
        "and is the correct accessor for binary uploads.\n" +
        "Example:\n" +
        "  (http-request-body-bytes req) => #u8(72 101 108 108 111)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeHttpRequest req = (SchemeHttpRequest) Value.AsNativeValue(arguments[0]).value;
        return req.BodyBytes == null ? Value.F : (object) req.BodyBytes;
    }
}
