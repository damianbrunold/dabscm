using System.Threading;

namespace scheme;

public class PrimitiveThreadYieldB : Primitive
{
    public override string Name() => "thread-yield!";

    public override string Info() =>
        "Syntax: (thread-yield!)\n" +
        "Library: (srfi 18)\n" +
        "Description: Causes the current thread to yield the processor to other threads.\n" +
        "Example:\n" +
        "  (thread-yield!)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        Thread.Yield();
        return Value.NIL;
    }
}
