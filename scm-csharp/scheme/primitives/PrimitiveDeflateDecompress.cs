using System.IO.Compression;

namespace scheme;

public class PrimitiveDeflateDecompress : Primitive
{
    public override string Name() => "deflate-decompress";

    public override string Info() =>
        "Syntax: (deflate-decompress bytevector)\n" +
        "Library: (scm compression)\n" +
        "Description: Decompresses a raw DEFLATE-compressed (RFC 1951) bytevector\n" +
        "  and returns the original bytevector.\n" +
        "Example:\n" +
        "  (utf8->string (deflate-decompress (deflate-compress (string->utf8 \"hello\")))) => \"hello\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        byte[] input = Value.AsBytevector(arguments[0]);

        using var inputStream = new MemoryStream(input);
        using var stream = new DeflateStream(inputStream, CompressionMode.Decompress);
        using var output = new MemoryStream();
        stream.CopyTo(output);
        return output.ToArray();
    }
}
