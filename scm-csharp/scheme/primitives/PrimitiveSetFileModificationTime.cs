using System;
using System.IO;

namespace scheme;

public class PrimitiveSetFileModificationTime : Primitive
{
    public override string Name()
    {
        return "set-file-modification-time!";
    }

    public override string Info()
    {
        return
            "Syntax: (set-file-modification-time! path millis)\n" +
            "Library: (scm fs)\n" +
            "Description: Sets the last-modification time of the file or directory at path to millis (milliseconds since the Unix epoch, UTC). Returns unspecified on success, #f on failure. The unit matches the value returned by file-modification-timestamp.\n" +
            "Example:\n" +
            "  (set-file-modification-time! \"dir\" (file-modification-timestamp \"src\"))";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        var path = LongPath.Wlp(new String(Value.AsString(arguments[0])));
        var millis = Value.AsInteger(arguments[1]);
        try
        {
            var when = DateTimeOffset.FromUnixTimeMilliseconds(millis).UtcDateTime;
            if (Directory.Exists(path)) Directory.SetLastWriteTimeUtc(path, when);
            else File.SetLastWriteTimeUtc(path, when);
            return new Values();
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
