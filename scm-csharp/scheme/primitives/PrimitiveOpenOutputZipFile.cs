using System.IO.Compression;

namespace scheme;

public class PrimitiveOpenOutputZipFile : Primitive
{
    public override string Name()
    {
        return "open-output-zip-file";
    }

    public override string Info()
    {
        return
            "Syntax: (open-output-zip-file filename)\n" +
            "Library: (scm core)\n" +
            "Description: Creates a new ZIP archive at the given filename and returns a ZIP writer object. Entries can be added using zip-add-text-entry or zip-add-binary-entry.\n" +
            "Example:\n" +
            "  (define z (open-output-zip-file \"archive.zip\"))\n" +
            "  (zip-add-text-entry z \"hello.txt\" \"Hello, world!\")\n" +
            "  (close-output-zip z)";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        string filename = new(Value.AsString(arguments[0]));
        try
        {
            var output = new ZipOutput
            {
                zip = new ZipArchive(new FileStream(filename, FileMode.Create), ZipArchiveMode.Create)
            };
            return new NativeValue(output);
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + " failed: ~s", e.Message);
        }
    }
}
