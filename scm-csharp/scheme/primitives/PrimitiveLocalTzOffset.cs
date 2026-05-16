namespace scheme;

public class PrimitiveLocalTzOffset : Primitive
{
    public override string Name() => "%local-tz-offset";

    public override string Info() =>
        "Syntax: (%local-tz-offset)\n" +
        "Library: (srfi 19)\n" +
        "Description: Internal primitive. Returns the local timezone offset from UTC in seconds.\n" +
        "Example:\n" +
        "  (%local-tz-offset) => 3600  ; UTC+1";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        return (long)TimeZoneInfo.Local.GetUtcOffset(DateTimeOffset.UtcNow).TotalSeconds;
    }
}
