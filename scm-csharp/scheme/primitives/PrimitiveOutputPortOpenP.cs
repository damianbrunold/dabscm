namespace scheme;

public class PrimitiveOutputPortOpenP : Primitive
{
    public override string Name() => "output-port-open?";
    public override string Info() =>
        "Syntax: (output-port-open? port)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns #t if port is still open, otherwise returns #f.\n" +
        "Example:\n" +
        "  (define p (open-output-string))\n" +
        "  (output-port-open? p) => #t\n" +
        "  (close-output-port p)\n" +
        "  (output-port-open? p) => #f";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsBinaryOutputPort(arguments[0]))
            return Value.AsBinaryOutputPort(arguments[0]).IsOpen;
        if (arguments[0] is TextOutputStream tos)
            return tos.IsOpen;
        return true;
    }
}
