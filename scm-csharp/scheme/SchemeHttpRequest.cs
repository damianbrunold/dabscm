using System.Collections.Generic;
using System.IO;
using System.Text;

namespace scheme;

public class SchemeHttpRequest
{
    // Default request timeout in seconds. A value <= 0 means "no timeout".
    public const int DefaultTimeoutSeconds = 600;

    public string Method;
    public string Url;
    public List<(string Name, string Value)> Headers;
    public string? Body;        // UTF-8 view of BodyBytes (for back-compat).
    public byte[]? BodyBytes;   // null if no body — the raw, byte-correct body.
    public string? BodyFile;    // a large body received by tcp-http-serve, spooled to a file
                                // (BodyBytes and Body are then read from it on demand)
    public int TimeoutSeconds = DefaultTimeoutSeconds; // <= 0 means no timeout
    public bool FollowRedirects = true; // false: http-send returns the 3xx itself

    public SchemeHttpRequest(string method, string url, List<(string, string)> headers, string? body)
        : this(method, url, headers, body, null)
    {
    }

    public SchemeHttpRequest(string method, string url, List<(string, string)> headers,
                             string? body, byte[]? bodyBytes)
    {
        Method = method;
        Url = url;
        Headers = headers;
        Body = body;
        BodyBytes = bodyBytes;
    }

    // The body bytes, read from the spool file if needed; null if none.
    public byte[]? GetBodyBytes()
    {
        if (BodyBytes == null && BodyFile != null)
        {
            try { BodyBytes = File.ReadAllBytes(BodyFile); }
            catch (IOException e) { throw new SchemeError("http-request-body: cannot read the spooled body: ~a", e.Message); }
        }
        return BodyBytes;
    }

    // The body decoded as UTF-8; null if none.
    public string? GetBody()
    {
        if (Body == null && GetBodyBytes() != null) Body = Encoding.UTF8.GetString(BodyBytes!);
        return Body;
    }

    public override string ToString() => $"#<http-request {Method} {Url}>";
}
