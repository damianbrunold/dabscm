using System.Collections.Generic;

namespace scheme;

public class PrimitiveMakeHttpRequest : Primitive
{
    public override string Name() => "make-http-request";

    public override string Info() =>
        "Syntax: (make-http-request method url headers body)\n" +
        "Library: (scm net http request)\n" +
        "Description: Creates an HTTP request object. headers is an alist of (name . value) pairs. body is a string or #f.\n" +
        "Example:\n" +
        "  (make-http-request \"GET\" \"/\" '() #f)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 4, 4);
        string method = new String(Value.AsString(arguments[0]));
        string url = new String(Value.AsString(arguments[1]));
        List<(string, string)> headers = new();
        object hlist = arguments[2];
        while (hlist != Value.NIL)
        {
            Pair hp = Value.AsPair(hlist);
            Pair kv = (Pair)hp.car;
            string key = new String(Value.AsString(kv.car));
            string val = new String(Value.AsString(kv.cdr));
            headers.Add((key, val));
            hlist = hp.cdr;
        }
        string? body = arguments[3].Equals(Value.F) ? null : new String(Value.AsString(arguments[3]));
        return new NativeValue(new SchemeHttpRequest(method, url, headers, body));
    }
}
