using System.Diagnostics;

namespace scheme;

public class PrimitiveThreadNanosecond : Primitive
{
    public override string Name() => "%thread-nanosecond";

    public override string Info() =>
        "Syntax: (%thread-nanosecond)\n" +
        "Library: (scm core)\n" +
        "Description: Internal primitive. Returns current thread CPU time as a pair (seconds . nanoseconds). Falls back to process CPU time on platforms without per-thread measurement.\n" +
        "Example:\n" +
        "  (%thread-nanosecond) => (2 . 100000000)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        // .NET does not provide per-thread CPU time without P/Invoke;
        // fall back to process CPU time.
        long ticks = Process.GetCurrentProcess().TotalProcessorTime.Ticks;
        long seconds = ticks / TimeSpan.TicksPerSecond;
        long nanos = (ticks % TimeSpan.TicksPerSecond) * 100L;
        return new Pair(seconds, nanos);
    }
}
