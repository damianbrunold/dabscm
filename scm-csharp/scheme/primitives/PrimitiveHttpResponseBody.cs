namespace scheme;

public class PrimitiveHttpResponseBody : Primitive
{
    public override string Name() => "http-response-body";

    public override string Info() =>
        "Syntax: (http-response-body response)\n" +
        "Library: (scm net http response)\n" +
        "Description: Returns the body of the HTTP response. If the response was created with a bytevector body, returns a bytevector; otherwise returns a string.\n" +
        "Example:\n" +
        "  (http-response-body resp) => \"Hello, world!\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeHttpResponse resp = (SchemeHttpResponse) Value.AsNativeValue(arguments[0]).value;
        if (resp.BodyBytes != null) return resp.BodyBytes;
        return resp.Body.ToCharArray();
    }
}
