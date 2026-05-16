using System.Collections.Generic;
using System.Text;

namespace scheme;

public class SchemeHttpResponse
{
    public int Status;
    public List<(string Name, string Value)> Headers;
    public string Body;
    public byte[]? BodyBytes;

    public SchemeHttpResponse(int status, List<(string, string)> headers, string body)
    {
        Status = status;
        Headers = headers;
        Body = body;
        BodyBytes = null;
    }

    public SchemeHttpResponse(int status, List<(string, string)> headers, byte[] bodyBytes)
    {
        Status = status;
        Headers = headers;
        Body = "";
        BodyBytes = bodyBytes;
    }

    public byte[] GetBodyBytes() => BodyBytes ?? Encoding.UTF8.GetBytes(Body);

    public override string ToString() => $"#<http-response {Status}>";
}
