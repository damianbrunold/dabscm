using System.IO.Compression;

namespace scheme;

public class PrimitiveOpenOutputZipBytevector : Primitive
{
    public override string Name() => "open-output-zip-bytevector";

    public override string Info() =>
        "Syntax: (open-output-zip-bytevector)\n" +
        "Library: (scm zip)\n" +
        "Description: Creates a new in-memory ZIP archive and returns a ZIP writer object. " +
        "After writing entries and calling close-output-zip, use get-output-zip-bytevector to retrieve the bytes.\n" +
        "Example:\n" +
        "  (let ((z (open-output-zip-bytevector)))\n" +
        "    (zip-add-text-entry z \"hello.txt\")\n" +
        "    (close-output-zip z)\n" +
        "    (get-output-zip-bytevector z))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        var mem = new MemoryStream();
        var output = new ZipOutput
        {
            mem_strm = mem,
            zip = new ZipArchive(mem, ZipArchiveMode.Create, leaveOpen: true)
        };
        return new NativeValue(output);
    }
}
