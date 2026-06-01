using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;

namespace scheme;

public class PrimitiveHttpGet : Primitive
{
    public override string Name() => "http-get";

    public override string Info() =>
        "Syntax: (http-get url) (http-get url headers) (http-get url headers timeout-seconds)\n" +
        "Library: (scm net http client)\n" +
        "Description: Performs an HTTP GET request and returns an http-response object. " +
        "Optional headers is an alist of (name . value) pairs. " +
        "Optional timeout-seconds overrides the default request timeout (600s); <= 0 means no timeout.\n" +
        "Example:\n" +
        "  (define resp (http-get \"http://example.com/\"))\n" +
        "  (http-response-status resp) => 200";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        string url = new String(Value.AsString(arguments[0]));
        int timeoutSeconds = arguments.Length == 3
            ? (int)Value.AsInteger(arguments[2])
            : SchemeHttpRequest.DefaultTimeoutSeconds;
        using var client = new HttpClient();
        client.Timeout = timeoutSeconds > 0
            ? System.TimeSpan.FromSeconds(timeoutSeconds)
            : System.Threading.Timeout.InfiniteTimeSpan;
        if (arguments.Length >= 2)
        {
            object hlist = arguments[1];
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
        var response = client.GetAsync(url).GetAwaiter().GetResult();
        return BuildResponse(response);
    }

    internal static NativeValue BuildResponse(HttpResponseMessage response)
    {
        int status = (int) response.StatusCode;
        List<(string, string)> headers = new();
        foreach (var h in response.Headers)
            foreach (var v in h.Value)
                headers.Add((h.Key, v));
        string body = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
        return new NativeValue(new SchemeHttpResponse(status, headers, body));
    }
}
