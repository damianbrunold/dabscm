using System.Text;
using System.IO;
using System.IO.Compression;

namespace scheme;

public class PrimitiveOpenInputFile : Primitive
{
    public override string Name()
    {
        return "open-input-file";
    }

    public override string Info()
    {
        return
            "Syntax: (open-input-file filename)\n" +
            "        (open-input-file filename option ...)\n" +
            "Library: (scheme file)\n" +
            "Description: Takes a filename and returns a textual input port that reads characters from the named file. It is an error if the file cannot be opened.\n" +
            "  As a non-standard extension, up to two optional arguments may follow the filename. They are symbols (strings are also accepted):\n" +
            "    - an encoding name selects the character encoding (default 'utf-8; also 'latin-1 / 'iso-8859-1, 'utf-16, 'utf-16-le)\n" +
            "    - 'deflate decompresses a DEFLATE-compressed file while reading (as written by open-output-file ... 'deflate)\n" +
            "Example:\n" +
            "  (define p (open-input-file \"data.txt\"))\n" +
            "  (read-char p) => first character of file\n" +
            "  (open-input-file \"legacy.txt\" 'latin-1)  ; decode as Latin-1\n" +
            "  (open-input-file \"data.z\" 'deflate)      ; read compressed input";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        string filename = new String(Value.AsString(arguments[0]));
        string path = LongPath.Wlp(filename);
        if (!File.Exists(path))
        {
            throw new SchemeError(pos, new FileErrorObject("open-input-file: file not found", new object[] { filename }));
        }
        try
        {
            Encoding encoding = Encoding.UTF8;
            bool deflate = false;
            for (var i = 1; i < arguments.Length; i++)
            {
                string arg;
                if (Value.IsSymbol(arguments[i]))
                {
                    arg = Value.AsSymbol(arguments[i]);
                }
                else
                {
                    arg = new String(Value.AsString(arguments[i]));
                }
                if (Encodings.IsEncoding(arg))
                {
                    encoding = Encodings.GetEncoding(arg);
                }
                else if (arg.Equals("deflate"))
                {
                    deflate = true;
                }
            }
            if (deflate)
            {
                return new TextStream(
                    new StreamReader(
                        new DeflateStream(
                            new FileStream(
                                path,
                                FileMode.Open,
                                FileAccess.Read,
                                FileShare.ReadWrite
                            ),
                            CompressionMode.Decompress
                        ),
                        encoding
                    ),
                    filename
                );
            }
            else
            {
                return new TextStream(
                    new StreamReader(
                        new FileStream(
                            path,
                            FileMode.Open,
                            FileAccess.Read,
                            FileShare.ReadWrite
                        ),
                        encoding
                    ),
                    filename
                );
            }
        }
        catch (Exception)
        {
            throw new SchemeError(pos, new FileErrorObject("open-input-file: io error", new object[] { filename }));
        }
    }
}
