namespace scheme;

public class PrimitiveThreadSpecific : Primitive
{
    public override string Name() => "thread-specific";

    public override string Info() =>
        "Syntax: (thread-specific thread)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns the thread-specific data associated with the thread.\n" +
        "Example:\n" +
        "  (thread-specific (current-thread)) => ()";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeThread t = (SchemeThread) Value.AsNativeValue(arguments[0]).value;
        return t.specific;
    }
}
