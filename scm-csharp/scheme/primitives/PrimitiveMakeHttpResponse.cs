using System.Collections.Generic;

namespace scheme;

public class PrimitiveMakeHttpResponse : Primitive
{
    public override string Name() => "make-http-response";

    public override string Info() =>
        "Syntax: (make-http-response status headers body)\n" +
        "Library: (scm net http response)\n" +
        "Description: Creates an HTTP response object. status is an integer, headers is an alist, body is a string or bytevector.\n" +
        "Example:\n" +
        "  (make-http-response 200 '() \"OK\")";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        int status = IntegerMath.ToInt(arguments[0]);
        List<(string, string)> headers = new();
        object hlist = arguments[1];
        while (hlist != Value.NIL)
        {
            Pair hp = Value.AsPair(hlist);
            Pair kv = (Pair)hp.car;
            string key = new String(Value.AsString(kv.car));
            string val = new String(Value.AsString(kv.cdr));
            headers.Add((key, val));
            hlist = hp.cdr;
        }
        if (Value.IsBytevector(arguments[2]))
        {
            byte[] bytes = Value.AsBytevector(arguments[2]);
            return new NativeValue(new SchemeHttpResponse(status, headers, bytes));
        }
        string body = new String(Value.AsString(arguments[2]));
        return new NativeValue(new SchemeHttpResponse(status, headers, body));
    }
}
