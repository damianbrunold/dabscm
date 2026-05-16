namespace scheme;

public class PrimitiveCurrentThread : Primitive
{
    public override string Name() => "current-thread";

    public override string Info() =>
        "Syntax: (current-thread)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns the current thread object.\n" +
        "Example:\n" +
        "  (thread? (current-thread)) => #t";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        SchemeThread? t = SchemeThread.CurrentThread;
        if (t == null)
            throw new SchemeError(pos, "current-thread: no current thread");
        return new NativeValue(t);
    }
}
