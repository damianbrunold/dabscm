using System;
using System.IO;
using System.IO.Compression;

namespace scheme;

public class PrimitiveZipAddFileEntry : Primitive
{
    public override string Name() => "zip-add-file-entry";

    public override string Info() =>
        "Syntax: (zip-add-file-entry zip name path [compress?])\n" +
        "Library: (scm zip)\n" +
        "Description: Adds the file at path to the ZIP archive zip as the entry named name, reading it in\n" +
        "  pieces, so the file may be larger than memory. The entry is stored uncompressed unless\n" +
        "  compress? is true: images, videos and other compressed formats gain nothing from deflating.\n" +
        "Example:\n" +
        "  (zip-add-file-entry zip \"assets/video.mp4\" \"/var/lib/app/video.mp4\")";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 4);
        try
        {
            ZipOutput output = (ZipOutput) Value.AsNativeValue(arguments[0]).value;
            string name = new(Value.AsString(arguments[1]));
            string path = new(Value.AsString(arguments[2]));
            bool compress = arguments.Length > 3 && arguments[3] != Value.F;
            output.text_strm?.Dispose();
            output.bin_strm?.Dispose();
            output.text_strm = null;
            output.bin_strm = null;
            var entry = output.zip!.CreateEntry(name,
                compress ? CompressionLevel.Optimal : CompressionLevel.NoCompression);
            var modified = new DateTimeOffset(File.GetLastWriteTimeUtc(path));
            var zipEpoch = new DateTimeOffset(1980, 1, 1, 0, 0, 0, TimeSpan.Zero);
            entry.LastWriteTime = modified < zipEpoch ? zipEpoch : modified;
            using (var file = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
            using (var stream = entry.Open())
            {
                file.CopyTo(stream, 65536);
            }
            return new Values();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + " failed, ~s", e.Message);
        }
    }
}
