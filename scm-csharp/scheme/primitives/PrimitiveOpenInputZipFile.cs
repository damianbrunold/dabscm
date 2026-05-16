using System.IO.Compression;

namespace scheme;

public class PrimitiveOpenInputZipFile : Primitive
{
    public override string Name()
    {
        return "open-input-zip-file";
    }

    public override string Info()
    {
        return
            "Syntax: (open-input-zip-file filename)\n" +
            "Library: (scm zip)\n" +
            "Description: Opens an existing ZIP archive at filename for reading and returns a ZIP reader object.\n" +
            "Example:\n" +
            "  (define z (open-input-zip-file \"archive.zip\"))\n" +
            "  (zip-entry-names z)\n" +
            "  (close-input-zip z)";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        try
        {
            string filename = new(Value.AsString(arguments[0]));
            var zip = new ZipArchive(new FileStream(filename, FileMode.Open, FileAccess.Read), ZipArchiveMode.Read);
            return new NativeValue(new ZipInput(zip));
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + " failed, ~s", e.Message);
        }
    }
}
