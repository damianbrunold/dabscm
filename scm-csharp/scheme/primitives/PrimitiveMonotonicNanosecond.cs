using System.Diagnostics;

namespace scheme;

public class PrimitiveMonotonicNanosecond : Primitive
{
    private static readonly long Frequency = Stopwatch.Frequency;

    public override string Name() => "%monotonic-nanosecond";

    public override string Info() =>
        "Syntax: (%monotonic-nanosecond)\n" +
        "Library: (scm core)\n" +
        "Description: Internal primitive. Returns monotonic clock time as a pair (seconds . nanoseconds).\n" +
        "Example:\n" +
        "  (%monotonic-nanosecond) => (12345 . 678000000)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        long timestamp = Stopwatch.GetTimestamp();
        long seconds = timestamp / Frequency;
        long remainderTicks = timestamp % Frequency;
        long nanos = remainderTicks * 1_000_000_000L / Frequency;
        return new Pair(seconds, nanos);
    }
}
