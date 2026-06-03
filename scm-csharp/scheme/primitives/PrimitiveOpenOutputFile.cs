using System.Text;
using System.IO;
using System.IO.Compression;

namespace scheme;

public class PrimitiveOpenOutputFile : Primitive
{
    public override string Name()
    {
        return "open-output-file";
    }

    public override string Info()
    {
        return
            "Syntax: (open-output-file filename)\n" +
            "        (open-output-file filename option ...)\n" +
            "Library: (scheme file)\n" +
            "Description: Takes a filename and returns a textual output port that writes characters to the named file. The file is created or truncated. It is an error if the file cannot be opened.\n" +
            "  As a non-standard extension, up to three optional arguments may follow the filename. They are symbols (strings are also accepted):\n" +
            "    - an encoding name selects the character encoding (default 'utf-8; also 'utf-8-bom, 'latin-1 / 'iso-8859-1, 'utf-16, 'utf-16-le)\n" +
            "    - 'deflate writes a DEFLATE-compressed stream (read it back with open-input-file ... 'deflate)\n" +
            "    - 'append appends to the file instead of truncating it\n" +
            "Example:\n" +
            "  (define p (open-output-file \"out.txt\"))\n" +
            "  (write-char #\\A p)\n" +
            "  (open-output-file \"log.txt\" 'append 'latin-1)  ; append, Latin-1\n" +
            "  (open-output-file \"data.z\" 'deflate)           ; compressed output";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 4);
        string filename = new String(Value.AsString(arguments[0]));
        string path = LongPath.Wlp(filename);
        try
        {
            Encoding encoding = Encodings.GetEncoding("utf-8");
            bool append = false;
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
                else if (arg.Equals("append"))
                {
                    append = true;
                }
            }
            if (append)
            {
                if (deflate)
                {
                    return new TextOutputStream(new StreamWriter(
                        new DeflateStream(
                            new FileStream(
                                path,
                                FileMode.Append,
                                FileAccess.Write,
                                FileShare.Read
                            ),
                            CompressionMode.Compress
                        ),
                        encoding,
                        8192
                    ));
                }
                else
                {
                    return new TextOutputStream(new StreamWriter(
                        new FileStream(
                            path,
                            FileMode.Append,
                            FileAccess.Write,
                            FileShare.Read
                        ),
                        encoding,
                        8192
                    ));
                }
            }
            else
            {
                if (deflate)
                {
                    return new TextOutputStream(new StreamWriter(
                        new DeflateStream(
                            new FileStream(
                                path,
                                FileMode.Create,
                                FileAccess.Write,
                                FileShare.Read
                            ),
                            CompressionMode.Compress
                        ),
                        encoding,
                        8192
                    ));
                }
                else
                {
                    return new TextOutputStream(new StreamWriter(
                        new FileStream(
                            path,
                            FileMode.Create,
                            FileAccess.Write,
                            FileShare.Read
                        ),
                        encoding,
                        8192
                    ));
                }
            }
        }
        catch (Exception)
        {
            throw new SchemeError(pos, new FileErrorObject("open-output-file: io failure", new object[] { filename }));
        }
    }
}
