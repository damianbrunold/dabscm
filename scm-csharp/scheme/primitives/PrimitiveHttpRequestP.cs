namespace scheme;

public class PrimitiveHttpRequestP : Primitive
{
    public override string Name() => "http-request?";

    public override string Info() =>
        "Syntax: (http-request? x)\n" +
        "Library: (scm net http request)\n" +
        "Description: Returns #t if x is an HTTP request object.\n" +
        "Example:\n" +
        "  (http-request? (make-http-request \"GET\" \"/\" '() #f)) => #t";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsNativeValue(arguments[0]) && Value.AsNativeValue(arguments[0]).value is SchemeHttpRequest
            ? Value.T : Value.F;
    }
}
