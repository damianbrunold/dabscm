using System;
using System.IO;

namespace scheme;

public class PrimitiveZipExtractEntry : Primitive
{
    public override string Name() => "zip-extract-entry";

    public override string Info() =>
        "Syntax: (zip-extract-entry zip name path [max-bytes])\n" +
        "Library: (scm zip)\n" +
        "Description: Writes the contents of the entry named name to the file at path, in pieces, so the\n" +
        "  entry may be larger than memory, and returns the number of bytes written. With max-bytes, an\n" +
        "  entry that unpacks to more raises an error (whatever size the archive declares) and the\n" +
        "  partial file is deleted.\n" +
        "Example:\n" +
        "  (zip-extract-entry z \"video.mp4\" \"/tmp/video.mp4\" (* 1024 1024 1024)) => 52428800";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 4);
        ZipInput input = (ZipInput) Value.AsNativeValue(arguments[0]).value;
        string name = new(Value.AsString(arguments[1]));
        string path = new(Value.AsString(arguments[2]));
        long max = arguments.Length > 3 ? IntegerMath.ToLong(arguments[3]) : long.MaxValue;
        var entry = input.zip.GetEntry(name);
        if (entry == null)
            throw new SchemeError(pos, Name() + ": entry not found, ~s", name);
        long total = 0;
        bool tooLarge = false;
        try
        {
            using var stream = entry.Open();
            using var file = new FileStream(path, FileMode.Create, FileAccess.Write);
            var buf = new byte[65536];
            int n;
            while ((n = stream.Read(buf, 0, buf.Length)) > 0)
            {
                total += n;
                if (total > max) { tooLarge = true; break; }
                file.Write(buf, 0, n);
            }
        }
        catch (Exception e)
        {
            try { File.Delete(path); } catch { }
            throw new SchemeError(pos, Name() + " failed, ~s", e.Message);
        }
        if (tooLarge)
        {
            try { File.Delete(path); } catch { }
            throw new SchemeError(pos, Name() + ": entry ~s is larger than ~a bytes", name, max);
        }
        return total;
    }
}
