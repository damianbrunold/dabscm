namespace scheme;

public class PrimitiveHttpResponseHeaders : Primitive
{
    public override string Name() => "http-response-headers";

    public override string Info() =>
        "Syntax: (http-response-headers response)\n" +
        "Library: (scm net http response)\n" +
        "Description: Returns the headers of the HTTP response as an alist of (name . value) pairs.\n" +
        "Example:\n" +
        "  (http-response-headers resp) => ((\"Content-Type\" . \"text/html\"))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeHttpResponse resp = (SchemeHttpResponse) Value.AsNativeValue(arguments[0]).value;
        object result = Value.NIL;
        for (int i = resp.Headers.Count - 1; i >= 0; i--)
        {
            Pair kv = new Pair(resp.Headers[i].Name.ToCharArray(), resp.Headers[i].Value.ToCharArray());
            result = new Pair(kv, result);
        }
        return result;
    }
}
