namespace scheme;

public class PrimitiveThreadSpecificSetB : Primitive
{
    public override string Name() => "thread-specific-set!";

    public override string Info() =>
        "Syntax: (thread-specific-set! thread obj)\n" +
        "Library: (srfi 18)\n" +
        "Description: Sets the thread-specific data associated with the thread.\n" +
        "Example:\n" +
        "  (thread-specific-set! (current-thread) 42)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        SchemeThread t = (SchemeThread) Value.AsNativeValue(arguments[0]).value;
        t.specific = arguments[1];
        return Value.NIL;
    }
}
