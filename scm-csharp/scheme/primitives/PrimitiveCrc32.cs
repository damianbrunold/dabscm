namespace scheme;

public class PrimitiveCrc32 : Primitive
{
    public override string Name() => "crc32";

    public override string Info() =>
        "Syntax: (crc32 bytevector [start [end]])\n" +
        "Library: (scm png)\n" +
        "Description: Computes the IEEE CRC-32 checksum (polynomial 0xEDB88320,\n" +
        "  as used by PNG, gzip, zip) of bytevector and returns it as an exact\n" +
        "  non-negative integer in [0, 2^32).\n" +
        "Example:\n" +
        "  (crc32 (string->utf8 \"123456789\")) => 3421780262";

    private static readonly uint[] Table = BuildTable();

    private static uint[] BuildTable()
    {
        var t = new uint[256];
        for (uint i = 0; i < 256; i++)
        {
            uint c = i;
            for (int k = 0; k < 8; k++)
                c = ((c & 1) != 0) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
            t[i] = c;
        }
        return t;
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        byte[] input = Value.AsBytevector(arguments[0]);
        int start = arguments.Length > 1 ? (int)(long)arguments[1] : 0;
        int end = arguments.Length > 2 ? (int)(long)arguments[2] : input.Length;
        uint c = 0xFFFFFFFFu;
        for (int i = start; i < end; i++)
            c = Table[(c ^ input[i]) & 0xFF] ^ (c >> 8);
        return (long)(c ^ 0xFFFFFFFFu);
    }
}
