using System.IO;

namespace scheme;

public class PrimitiveOpenBinaryOutputFile : Primitive
{
    public override string Name() => "open-binary-output-file";
    public override string Info() =>
        "Syntax: (open-binary-output-file filename)\n" +
        "Library: (scheme file)\n" +
        "Description: Opens the named file for binary output and returns a binary output port. Creates or truncates the file. Raises a file-error on failure.\n" +
        "Example:\n" +
        "  (let ((p (open-binary-output-file \"out.bin\")))\n" +
        "    (write-u8 42 p))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        string filename = new String(Value.AsString(arguments[0]));
        try
        {
            return new BinaryOutputStream(new FileStream(filename, FileMode.Create, FileAccess.Write, FileShare.Read));
        }
        catch (Exception)
        {
            throw new SchemeError(pos, new FileErrorObject("open-binary-output-file: io failure", new object[] { filename }));
        }
    }
}
