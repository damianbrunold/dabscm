using System.Collections.Generic;
using System.Text;

namespace scheme;

public class PrimitiveSocketReadLine : Primitive
{
    public override string Name() => "socket-read-line";

    public override string Info() =>
        "Syntax: (socket-read-line socket)\n" +
        "Library: (scm net sockets)\n" +
        "Description: Reads one line directly from the socket's raw underlying stream, byte\n" +
        "  by byte with no buffering, decoding the bytes as UTF-8. A trailing CR is dropped\n" +
        "  and the line is terminated by LF; the returned string does not include the line\n" +
        "  ending. Returns an end-of-file object if the stream is closed before any byte is\n" +
        "  read. Because it never buffers ahead, it is safe for line-oriented protocols (such\n" +
        "  as SMTP) where a buffered reader would consume bytes past a protocol boundary like\n" +
        "  a STARTTLS upgrade.\n" +
        "Example:\n" +
        "  (socket-read-line sock) => \"220 mail.example.com ESMTP\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeSocket ss = (SchemeSocket) Value.AsNativeValue(arguments[0]).value;
        try
        {
            var bytes = new List<byte>();
            bool any = false;
            int b;
            while ((b = ss.networkStream.ReadByte()) != -1)
            {
                any = true;
                if (b == '\n') break;
                if (b == '\r') continue;
                bytes.Add((byte) b);
            }
            if (!any) return Value.EOF;
            return Encoding.UTF8.GetString(bytes.ToArray()).ToCharArray();
        }
        catch (System.Exception e)
        {
            throw new SchemeError(pos, "socket-read-line: io failure: ~a", e.Message);
        }
    }
}
