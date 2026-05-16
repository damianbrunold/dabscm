using System.IO.Compression;

namespace scheme;

public class PrimitiveGzipDecompress : Primitive
{
    public override string Name() => "gzip-decompress";

    public override string Info() =>
        "Syntax: (gzip-decompress bytevector)\n" +
        "Library: (scm compression)\n" +
        "Description: Decompresses a GZip-compressed (RFC 1952) bytevector and returns\n" +
        "  the original bytevector.\n" +
        "Example:\n" +
        "  (utf8->string (gzip-decompress (gzip-compress (string->utf8 \"hello\")))) => \"hello\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        byte[] input = Value.AsBytevector(arguments[0]);

        using var inputStream = new MemoryStream(input);
        using var stream = new GZipStream(inputStream, CompressionMode.Decompress);
        using var output = new MemoryStream();
        stream.CopyTo(output);
        return output.ToArray();
    }
}
