namespace scheme;

public class PrimitiveHttpResponseP : Primitive
{
    public override string Name() => "http-response?";

    public override string Info() =>
        "Syntax: (http-response? x)\n" +
        "Library: (scm net http response)\n" +
        "Description: Returns #t if x is an HTTP response object.\n" +
        "Example:\n" +
        "  (http-response? (make-http-response 200 '() \"ok\")) => #t";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsNativeValue(arguments[0]) && Value.AsNativeValue(arguments[0]).value is SchemeHttpResponse
            ? Value.T : Value.F;
    }
}
