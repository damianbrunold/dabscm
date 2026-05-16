namespace scheme;

public class PrimitiveThreadName : Primitive
{
    public override string Name() => "thread-name";

    public override string Info() =>
        "Syntax: (thread-name thread)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns the name of the thread.\n" +
        "Example:\n" +
        "  (thread-name (make-thread (lambda () #t) 'my-thread)) => my-thread";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeThread t = (SchemeThread) Value.AsNativeValue(arguments[0]).value;
        return t.name;
    }
}
