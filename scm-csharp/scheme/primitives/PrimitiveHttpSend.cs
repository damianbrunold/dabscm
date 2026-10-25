using System.Collections.Generic;
using System.Net.Http;
using System.Text;

namespace scheme;

public class PrimitiveHttpSend : Primitive
{
    public override string Name() => "http-send";

    public override string Info() =>
        "Syntax: (http-send request)\n" +
        "Library: (scm net http client)\n" +
        "Description: Sends an HTTP request object and returns an http-response object.\n" +
        "Example:\n" +
        "  (http-send (make-http-request \"DELETE\" \"http://example.com/x\" '() #f))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeHttpRequest req = (SchemeHttpRequest) Value.AsNativeValue(arguments[0]).value;
        using var client = TlsTrust.CreateHttpClient(req.FollowRedirects);
        client.Timeout = req.TimeoutSeconds > 0
            ? System.TimeSpan.FromSeconds(req.TimeoutSeconds)
            : System.Threading.Timeout.InfiniteTimeSpan;
        var message = new HttpRequestMessage(new HttpMethod(req.Method), req.Url);
        if (req.BodyBytes != null)
            message.Content = new ByteArrayContent(req.BodyBytes);
        else if (req.Body != null)
            message.Content = new StringContent(req.Body, Encoding.UTF8);
        // Content-Type and the other entity headers belong to the content, not
        // the message: added to message.Headers they are silently dropped.
        foreach (var (name, value) in req.Headers)
        {
            if (message.Headers.TryAddWithoutValidation(name, value)) continue;
            if (message.Content == null) continue;
            message.Content.Headers.Remove(name);
            message.Content.Headers.TryAddWithoutValidation(name, value);
        }
        var response = client.SendAsync(message).GetAwaiter().GetResult();
        return PrimitiveHttpGet.BuildResponse(response);
    }
}
