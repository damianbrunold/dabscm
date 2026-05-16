namespace scheme;

public class PrimitiveThreadP : Primitive
{
    public override string Name() => "thread?";

    public override string Info() =>
        "Syntax: (thread? x)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns #t if x is a thread object.\n" +
        "Example:\n" +
        "  (thread? (make-thread (lambda () 1))) => #t";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsNativeValue(arguments[0]) && Value.AsNativeValue(arguments[0]).value is SchemeThread
            ? Value.T : Value.F;
    }
}
