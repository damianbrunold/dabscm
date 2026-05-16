namespace scheme;

public class PrimitiveHttpRequestMethod : Primitive
{
    public override string Name() => "http-request-method";

    public override string Info() =>
        "Syntax: (http-request-method request)\n" +
        "Library: (scm net http request)\n" +
        "Description: Returns the HTTP method of the request as a string.\n" +
        "Example:\n" +
        "  (http-request-method req) => \"GET\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeHttpRequest req = (SchemeHttpRequest) Value.AsNativeValue(arguments[0]).value;
        return req.Method.ToCharArray();
    }
}
