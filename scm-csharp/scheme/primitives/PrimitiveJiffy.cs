namespace scheme;

public class PrimitiveJiffy : Primitive
{
    private static readonly long UnixEpochMicroseconds =
        new DateTimeOffset(1970, 1, 1, 0, 0, 0, TimeSpan.Zero).Ticks / 10L;

    public override string Name() => "%jiffy";

    public override string Info() =>
        "Syntax: (%jiffy)\n" +
        "Library: (scm core)\n" +
        "Description: Internal primitive. Returns the number of microseconds elapsed since the Unix epoch (1970-01-01 00:00:00 UTC).\n" +
        "Example:\n" +
        "  (%jiffy) => 1700000000000000";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        return DateTimeOffset.UtcNow.Ticks / 10L - UnixEpochMicroseconds;
    }
}
