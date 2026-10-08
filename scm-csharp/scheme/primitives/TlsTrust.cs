using System;
using System.Net.Http;

namespace scheme;

// Shared TLS settings for the HTTP client primitives.
//
// SCM_TLS_INSECURE=1 (or true/yes) disables certificate and host name
// verification for the HTTP client (insecure; for broken intranet setups only).
// Without it the platform default validation is used (on Windows: the Windows
// certificate store).
public static class TlsTrust
{
    private static bool warned;

    public static bool InsecureRequested()
    {
        string? v = Environment.GetEnvironmentVariable("SCM_TLS_INSECURE");
        if (v == null) return false;
        v = v.Trim().ToLowerInvariant();
        return v == "1" || v == "true" || v == "yes";
    }

    public static HttpClient CreateHttpClient()
    {
        if (!InsecureRequested()) return new HttpClient();
        if (!warned)
        {
            warned = true;
            Console.Error.WriteLine(
                "warning: SCM_TLS_INSECURE is set, HTTPS certificate verification is disabled");
        }
        var handler = new HttpClientHandler
        {
            ServerCertificateCustomValidationCallback = (msg, cert, chain, errors) => true
        };
        return new HttpClient(handler, disposeHandler: true);
    }
}
