namespace scheme;

public class PrimitiveHttpRequestUrl : Primitive
{
    public override string Name() => "http-request-url";

    public override string Info() =>
        "Syntax: (http-request-url request)\n" +
        "Library: (scm net http request)\n" +
        "Description: Returns the URL of the HTTP request as a string.\n" +
        "Example:\n" +
        "  (http-request-url req) => \"/api/users\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeHttpRequest req = (SchemeHttpRequest) Value.AsNativeValue(arguments[0]).value;
        return req.Url.ToCharArray();
    }
}
