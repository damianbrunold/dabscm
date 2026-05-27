using System.Diagnostics;

namespace scheme;

public class PrimitiveProcessNanosecond : Primitive
{
    public override string Name() => "%process-nanosecond";

    public override string Info() =>
        "Syntax: (%process-nanosecond)\n" +
        "Library: (scm core)\n" +
        "Description: Internal primitive. Returns process CPU time as a pair (seconds . nanoseconds).\n" +
        "Example:\n" +
        "  (%process-nanosecond) => (5 . 230000000)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        long ticks = Process.GetCurrentProcess().TotalProcessorTime.Ticks;
        long seconds = ticks / TimeSpan.TicksPerSecond;
        long nanos = (ticks % TimeSpan.TicksPerSecond) * 100L;
        return new Pair(seconds, nanos);
    }
}
