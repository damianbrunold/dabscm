using System.IO;

namespace scheme;

public class PrimitiveOpenRandomAccessFile : Primitive
{
    public override string Name() => "open-random-access-file";
    public override string Info() =>
        "Syntax: (open-random-access-file filename mode)\n" +
        "Library: (scm random access)\n" +
        "Description: Opens filename for positioned (random-access) binary I/O and returns a random-access file handle. mode is a symbol or string: read opens an existing file read-only; write creates or truncates the file for read/write; update opens (creating if absent) for read/write without truncating. Raises a file-error on failure.\n" +
        "Example:\n" +
        "  (let ((f (open-random-access-file \"data.store\" 'write)))\n" +
        "    (random-access-file-write! f 0 #u8(1 2 3))\n" +
        "    (close-random-access-file f))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        string filename = new String(Value.AsString(arguments[0]));
        string mode = Value.IsSymbol(arguments[1])
            ? Value.AsSymbol(arguments[1])
            : new String(Value.AsString(arguments[1]));
        string path = LongPath.Wlp(filename);

        FileMode fm;
        FileAccess fa;
        switch (mode)
        {
            case "read":
                if (!File.Exists(path))
                    throw new SchemeError(pos, new FileErrorObject("open-random-access-file: file not found", new object[] { filename }));
                fm = FileMode.Open;
                fa = FileAccess.Read;
                break;
            case "write":
                fm = FileMode.Create;
                fa = FileAccess.ReadWrite;
                break;
            case "update":
                fm = FileMode.OpenOrCreate;
                fa = FileAccess.ReadWrite;
                break;
            default:
                throw new SchemeError(pos, "open-random-access-file: bad mode, ~s (expected read, write, or update)", mode);
        }

        try
        {
            var stream = new FileStream(path, fm, fa, FileShare.ReadWrite);
            return new NativeValue(new RandomAccessFileHandle(stream, filename));
        }
        catch (SchemeError) { throw; }
        catch (System.Exception)
        {
            throw new SchemeError(pos, new FileErrorObject("open-random-access-file: io error", new object[] { filename }));
        }
    }
}
