namespace scheme;

public class PrimitiveLocalTzOffset : Primitive
{
    public override string Name() => "%local-tz-offset";

    public override string Info() =>
        "Syntax: (%local-tz-offset [utc-seconds])\n" +
        "Library: (scm core)\n" +
        "Description: Internal primitive. Returns the local timezone offset from UTC in seconds,\n" +
        "  now or at the time utc-seconds (seconds since the epoch), so DST is taken into account.\n" +
        "Example:\n" +
        "  (%local-tz-offset) => 3600  ; UTC+1";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 1);
        var at = DateTimeOffset.UtcNow;
        if (arguments.Length > 0)
        {
            // clamped to the range of DateTimeOffset, with a day of margin for the offset
            var secs = Math.Max(-62135596800L + 86400, Math.Min(253402300799L - 86400, IntegerMath.ToLong(arguments[0])));
            at = DateTimeOffset.FromUnixTimeSeconds(secs);
        }
        return (long)TimeZoneInfo.Local.GetUtcOffset(at).TotalSeconds;
    }
}
