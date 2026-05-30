using System.IO;

namespace scheme;

public class PrimitiveOpenBinaryInputFile : Primitive
{
    public override string Name() => "open-binary-input-file";
    public override string Info() =>
        "Syntax: (open-binary-input-file filename)\n" +
        "Library: (scheme file)\n" +
        "Description: Opens the named file for binary input and returns a binary input port. Raises a file-error if the file cannot be opened.\n" +
        "Example:\n" +
        "  (let ((p (open-binary-input-file \"data.bin\")))\n" +
        "    (read-u8 p))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        string filename = new String(Value.AsString(arguments[0]));
        string path = LongPath.Wlp(filename);
        if (!File.Exists(path))
            throw new SchemeError(pos, new FileErrorObject("open-binary-input-file: file not found", new object[] { filename }));
        try
        {
            return new BinaryInputStream(new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite));
        }
        catch (Exception)
        {
            throw new SchemeError(pos, new FileErrorObject("open-binary-input-file: io error", new object[] { filename }));
        }
    }
}
