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
        using var client = new HttpClient();
        var message = new HttpRequestMessage(new HttpMethod(req.Method), req.Url);
        foreach (var (name, value) in req.Headers)
            message.Headers.TryAddWithoutValidation(name, value);
        if (req.Body != null)
            message.Content = new StringContent(req.Body, Encoding.UTF8);
        var response = client.SendAsync(message).GetAwaiter().GetResult();
        return PrimitiveHttpGet.BuildResponse(response);
    }
}
