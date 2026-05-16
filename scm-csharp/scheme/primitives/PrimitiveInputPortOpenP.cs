namespace scheme;

public class PrimitiveInputPortOpenP : Primitive
{
    public override string Name() => "input-port-open?";
    public override string Info() =>
        "Syntax: (input-port-open? port)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns #t if the input port is still open, otherwise returns #f.\n" +
        "Example:\n" +
        "  (let ((p (open-input-string \"abc\")))\n" +
        "    (close-input-port p)\n" +
        "    (input-port-open? p)) => #f";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsBinaryInputPort(arguments[0]))
            return Value.AsBinaryInputPort(arguments[0]).IsOpen;
        if (arguments[0] is TextStream ts)
            return ts.IsOpen;
        return true;
    }
}
