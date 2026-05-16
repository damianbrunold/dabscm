namespace scheme;

public class PrimitiveFileModificationDate : Primitive
{
    public override string Name()
    {
        return "file-modification-date";
    }

    public override string Info()
    {
        return
            "Syntax: (file-modification-date filename)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns the last modification time of the file as seconds since the Unix epoch (UTC).\n" +
            "Example:\n" +
            "  (file-modification-date \"data.txt\") => 1700000000";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var file = new String(Value.AsString(arguments[0]));
        var modified = File.GetLastWriteTimeUtc(file);
        return new DateTimeOffset(modified).ToUnixTimeSeconds();
    }
}
