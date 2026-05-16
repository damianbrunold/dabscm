using System.IO.Compression;

namespace scheme;

public class PrimitiveZlibDecompress : Primitive
{
    public override string Name() => "zlib-decompress";

    public override string Info() =>
        "Syntax: (zlib-decompress bytevector)\n" +
        "Library: (scm compression)\n" +
        "Description: Decompresses a ZLib-framed (RFC 1950) bytevector and returns\n" +
        "  the original bytevector.\n" +
        "Example:\n" +
        "  (utf8->string (zlib-decompress (zlib-compress (string->utf8 \"hello\")))) => \"hello\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        byte[] input = Value.AsBytevector(arguments[0]);

        using var inputStream = new MemoryStream(input);
        using var stream = new ZLibStream(inputStream, CompressionMode.Decompress);
        using var output = new MemoryStream();
        stream.CopyTo(output);
        return output.ToArray();
    }
}
