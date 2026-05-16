namespace scheme;

public class PrimitiveHttpRequestBody : Primitive
{
    public override string Name() => "http-request-body";

    public override string Info() =>
        "Syntax: (http-request-body request)\n" +
        "Library: (scm net http request)\n" +
        "Description: Returns the body of the HTTP request as a string, or #f if there is no body.\n" +
        "Example:\n" +
        "  (http-request-body req) => \"hello\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeHttpRequest req = (SchemeHttpRequest) Value.AsNativeValue(arguments[0]).value;
        return req.Body == null ? Value.F : (object) req.Body.ToCharArray();
    }
}
