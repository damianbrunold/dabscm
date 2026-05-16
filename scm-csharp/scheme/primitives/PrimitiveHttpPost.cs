using System.Collections.Generic;
using System.Net.Http;
using System.Text;

namespace scheme;

public class PrimitiveHttpPost : Primitive
{
    public override string Name() => "http-post";

    public override string Info() =>
        "Syntax: (http-post url body) (http-post url body headers)\n" +
        "Library: (scm net http client)\n" +
        "Description: Performs an HTTP POST request with the given body string and returns an http-response object.\n" +
        "Example:\n" +
        "  (http-post \"http://example.com/api\" \"{\\\"x\\\":1}\")";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 3);
        string url = new String(Value.AsString(arguments[0]));
        string body = new String(Value.AsString(arguments[1]));
        using var client = new HttpClient();
        if (arguments.Length == 3)
        {
            object hlist = arguments[2];
            while (hlist != Value.NIL)
            {
                Pair hp = Value.AsPair(hlist);
                Pair kv = (Pair)hp.car;
                string key = new String(Value.AsString(kv.car));
                string val = new String(Value.AsString(kv.cdr));
                client.DefaultRequestHeaders.TryAddWithoutValidation(key, val);
                hlist = hp.cdr;
            }
        }
        var content = new StringContent(body, Encoding.UTF8);
        var response = client.PostAsync(url, content).GetAwaiter().GetResult();
        return PrimitiveHttpGet.BuildResponse(response);
    }
}
