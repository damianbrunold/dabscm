using System.IO.Compression;

namespace scheme;

public class PrimitiveZipAddStoredEntry: Primitive
{
    public override string Name()
    {
        return "zip-add-stored-entry";
    }

    public override string Info()
    {
        return
            "Syntax: (zip-add-stored-entry zip name bytevector [timestamp])\n" +
            "Library: (scm zip)\n" +
            "Description: Creates a new uncompressed (STORED) entry named name in the\n" +
            "  ZIP archive zip and writes the entire bytevector as its content. Unlike\n" +
            "  zip-add-binary-entry, the data is stored without compression and must be\n" +
            "  provided in full. The optional timestamp is a Unix epoch in seconds.\n" +
            "  Returns void.\n" +
            "Example:\n" +
            "  (zip-add-stored-entry zip \"mimetype\" (string->utf8 \"application/xml\") 0)";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 4);
        try
        {
            ZipOutput output = (ZipOutput) Value.AsNativeValue(arguments[0]).value;
            string entryname = new(Value.AsString(arguments[1]));
            byte[] data = Value.AsBytevector(arguments[2]);
            output.text_strm?.Dispose();
            output.bin_strm?.Dispose();
            output.text_strm = null;
            output.bin_strm = null;
            var entry = output.zip!.CreateEntry(entryname, CompressionLevel.NoCompression);
            if (arguments.Length > 3)
            {
                var dt = DateTimeOffset.FromUnixTimeSeconds(IntegerMath.ToLong(arguments[3]));
                var zipEpoch = new DateTimeOffset(1980, 1, 1, 0, 0, 0, TimeSpan.Zero);
                entry.LastWriteTime = dt < zipEpoch ? zipEpoch : dt;
            }
            using (var stream = entry.Open())
            {
                stream.Write(data, 0, data.Length);
            }
            return new Values();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + " failed, ~s", e.Message);
        }
    }
}
