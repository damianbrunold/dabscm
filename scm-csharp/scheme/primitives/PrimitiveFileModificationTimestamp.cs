namespace scheme;

public class PrimitiveFileModificationTimestamp : Primitive
{
    public override string Name()
    {
        return "file-modification-timestamp";
    }

    public override string Info()
    {
        return
            "Syntax: (file-modification-timestamp filename)\n" +
            "Library: (scm system)\n" +
            "Description: Returns the last modification time of the file as a millisecond timestamp (milliseconds since the Unix epoch, UTC).\n" +
            "Example:\n" +
            "  (file-modification-timestamp \"data.txt\") => 1700000000000";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var file = new String(Value.AsString(arguments[0]));
        var modified = File.GetLastWriteTimeUtc(file);
        return new DateTimeOffset(modified).ToUnixTimeMilliseconds();
    }
}
