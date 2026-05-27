namespace scheme;

public class PrimitiveCurrentNanosecond : Primitive
{
    private static readonly long UnixEpochTicks =
        new DateTimeOffset(1970, 1, 1, 0, 0, 0, TimeSpan.Zero).Ticks;

    public override string Name() => "%current-nanosecond";

    public override string Info() =>
        "Syntax: (%current-nanosecond)\n" +
        "Library: (scm core)\n" +
        "Description: Internal primitive. Returns the current UTC time as a pair (seconds . nanoseconds) since the Unix epoch.\n" +
        "Example:\n" +
        "  (%current-nanosecond) => (1700000000 . 123456789)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        long ticks = DateTimeOffset.UtcNow.Ticks - UnixEpochTicks;
        long seconds = ticks / TimeSpan.TicksPerSecond;
        long nanos = (ticks % TimeSpan.TicksPerSecond) * 100L;
        return new Pair(seconds, nanos);
    }
}
