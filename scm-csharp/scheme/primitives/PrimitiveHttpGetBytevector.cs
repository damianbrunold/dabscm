using System;
using System.Collections.Generic;
using System.Net.Http;

namespace scheme;

public class PrimitiveHttpGetBytevector : Primitive
{
    public override string Name() => "http-get-bytevector";

    public override string Info() =>
        "Syntax: (http-get-bytevector url) (http-get-bytevector url headers) (http-get-bytevector url headers timeout-seconds)\n" +
        "Library: (scm net http client)\n" +
        "Description: Performs an HTTP GET request like http-get, but keeps the body as it\n" +
        "  arrived: http-response-body of the response returned is a bytevector. Use it for\n" +
        "  downloading binary files such as images or ZIP archives.\n" +
        "Example:\n" +
        "  (bytevector-length (http-response-body (http-get-bytevector \"http://example.com/a.zip\"))) => 81234";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        string url = new String(Value.AsString(arguments[0]));
        int timeoutSeconds = arguments.Length == 3
            ? (int)Value.AsInteger(arguments[2])
            : SchemeHttpRequest.DefaultTimeoutSeconds;
        using var client = TlsTrust.CreateHttpClient();
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
        var headers = PrimitiveHttpGet.ResponseHeaders(response);
        byte[] body = response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult();
        return new NativeValue(new SchemeHttpResponse((int)response.StatusCode, headers, body));
    }
}
