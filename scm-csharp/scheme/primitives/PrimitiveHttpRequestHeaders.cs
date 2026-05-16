namespace scheme;

public class PrimitiveHttpRequestHeaders : Primitive
{
    public override string Name() => "http-request-headers";

    public override string Info() =>
        "Syntax: (http-request-headers request)\n" +
        "Library: (scm net http request)\n" +
        "Description: Returns the headers of the HTTP request as an alist of (name . value) pairs.\n" +
        "Example:\n" +
        "  (http-request-headers req) => ((\"Host\" . \"example.com\"))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeHttpRequest req = (SchemeHttpRequest) Value.AsNativeValue(arguments[0]).value;
        object result = Value.NIL;
        for (int i = req.Headers.Count - 1; i >= 0; i--)
        {
            Pair kv = new Pair(req.Headers[i].Name.ToCharArray(), req.Headers[i].Value.ToCharArray());
            result = new Pair(kv, result);
        }
        return result;
    }
}
