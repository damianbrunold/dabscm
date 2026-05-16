namespace scheme;

public class PrimitiveTimestamp : Primitive
{
    public override string Name()
    {
        return "timestamp";
    }

    public override string Info()
    {
        return
            "Syntax: (timestamp)\n" +
            "Library: (scm system)\n" +
            "Description: Returns the current time as the number of milliseconds since the Unix epoch (January 1, 1970 UTC).\n" +
            "Example:\n" +
            "  (timestamp) => 1700000000000";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        return DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
    }
}
