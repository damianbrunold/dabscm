namespace scheme;

public class PrimitiveThreadTerminateB : Primitive
{
    public override string Name() => "thread-terminate!";

    public override string Info() =>
        "Syntax: (thread-terminate! thread)\n" +
        "Library: (srfi 18)\n" +
        "Description: Terminates the given thread. If the target is the current thread, " +
        "an error is raised.\n" +
        "Example:\n" +
        "  (thread-terminate! t)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeThread t = (SchemeThread) Value.AsNativeValue(arguments[0]).value;
        t.terminated = true;
        t.state = SchemeThreadState.TERMINATED;
        if (t == SchemeThread.CurrentThread)
            throw new SchemeError(pos, "thread terminated");
        return Value.NIL;
    }
}
