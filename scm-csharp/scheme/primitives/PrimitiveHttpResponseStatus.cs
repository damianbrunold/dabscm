namespace scheme;

public class PrimitiveHttpResponseStatus : Primitive
{
    public override string Name() => "http-response-status";

    public override string Info() =>
        "Syntax: (http-response-status response)\n" +
        "Library: (scm net http response)\n" +
        "Description: Returns the HTTP status code of the response as an integer.\n" +
        "Example:\n" +
        "  (http-response-status resp) => 200";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeHttpResponse resp = (SchemeHttpResponse) Value.AsNativeValue(arguments[0]).value;
        return (long) resp.Status;
    }
}
