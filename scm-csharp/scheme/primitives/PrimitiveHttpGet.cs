using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;

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
        "  The body is a string when the response is text (Content-Type text/*, JSON, XML,\n" +
        "  JavaScript, form data, any type with a charset parameter such as\n" +
        "  application/x-sexp; charset=utf-8, or none), decoded by its charset (UTF-8 by\n" +
        "  default), and a bytevector otherwise (images, archives, ...), as it arrived.\n" +
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
        return BuildResponse(response);
    }

    // The body as http-get, http-post and http-send return it: decoded to a
    // string when the Content-Type says it is text (or says nothing), the
    // bytes as they arrived otherwise. Decoding an image or an archive as
    // text would corrupt it beyond repair.
    internal static NativeValue BuildResponse(HttpResponseMessage response)
    {
        int status = (int) response.StatusCode;
        var headers = ResponseHeaders(response);
        var contentType = response.Content.Headers.ContentType;
        byte[] bytes = response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult();
        if (!IsText(contentType?.MediaType, contentType?.CharSet))
            return new NativeValue(new SchemeHttpResponse(status, headers, bytes));
        return new NativeValue(new SchemeHttpResponse(status, headers, Decode(bytes, contentType?.CharSet)));
    }

    // Content-Type, Content-Length and the other entity headers are kept on
    // the content in .NET; they are response headers all the same, as they
    // are in the Java implementation.
    internal static List<(string, string)> ResponseHeaders(HttpResponseMessage response)
    {
        List<(string, string)> headers = new();
        foreach (var h in response.Headers)
            foreach (var v in h.Value)
                headers.Add((h.Key, v));
        foreach (var h in response.Content.Headers)
            foreach (var v in h.Value)
                headers.Add((h.Key, v));
        return headers;
    }

    // Text: no type, text/*, the JSON/XML/JavaScript/form types, or any type
    // that names a charset (application/x-sexp; charset=utf-8) -- a charset
    // only makes sense for text. charset=binary is the one exception.
    internal static bool IsText(string? mediaType, string? charset = null)
    {
        if (string.IsNullOrWhiteSpace(mediaType)) return true;
        var t = mediaType.Trim().ToLowerInvariant();
        if (t.StartsWith("text/")) return true;
        var cs = charset?.Trim().Trim('"');
        if (!string.IsNullOrEmpty(cs) && !cs.Equals("binary", StringComparison.OrdinalIgnoreCase)) return true;
        if (t.EndsWith("+json") || t.EndsWith("+xml")) return true;
        return t is "application/json" or "application/xml" or "application/javascript"
            or "application/ecmascript" or "application/x-www-form-urlencoded"
            or "application/x-ndjson";
    }

    static string Decode(byte[] bytes, string? charset)
    {
        Encoding encoding = Encoding.UTF8;
        if (!string.IsNullOrWhiteSpace(charset))
        {
            try { encoding = Encoding.GetEncoding(charset.Trim().Trim('"')); }
            catch (Exception) { encoding = Encoding.UTF8; }
        }
        return encoding.GetString(bytes);
    }
}
