using System.IO.Compression;

namespace scheme;

public class PrimitiveDeflateCompress : Primitive
{
    public override string Name() => "deflate-compress";

    public override string Info() =>
        "Syntax: (deflate-compress bytevector [level])\n" +
        "Library: (scm compression)\n" +
        "Description: Compresses bytevector using raw DEFLATE (RFC 1951) and returns\n" +
        "  a bytevector. The optional level is an integer 0-9: 0 = no compression,\n" +
        "  1-3 = fastest, 4-6 = optimal (default), 7-9 = smallest size.\n" +
        "Example:\n" +
        "  (utf8->string (deflate-decompress (deflate-compress (string->utf8 \"hello\")))) => \"hello\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        byte[] input = Value.AsBytevector(arguments[0]);
        var level = arguments.Length > 1
            ? LevelFromInt((int)(long)arguments[1])
            : CompressionLevel.Optimal;

        using var output = new MemoryStream();
        using (var stream = new DeflateStream(output, level))
            stream.Write(input, 0, input.Length);
        return output.ToArray();
    }

    private static CompressionLevel LevelFromInt(int level) => level switch
    {
        0 => CompressionLevel.NoCompression,
        1 or 2 or 3 => CompressionLevel.Fastest,
        4 or 5 or 6 => CompressionLevel.Optimal,
        _ => CompressionLevel.SmallestSize,
    };
}
