using System.Collections.Generic;

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
    public int TimeoutSeconds = DefaultTimeoutSeconds; // <= 0 means no timeout

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

    public override string ToString() => $"#<http-request {Method} {Url}>";
}
