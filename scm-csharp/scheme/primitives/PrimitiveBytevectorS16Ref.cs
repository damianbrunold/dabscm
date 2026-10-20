namespace scheme;

public class PrimitiveBytevectorS16Ref : Primitive
{
    public override string Name() => "bytevector-s16-ref";
    public override string Info() =>
        "Syntax: (bytevector-s16-ref bv k endianness)\n" +
        "Library: (scm bytevector)\n" +
        "Description: Returns the signed 16-bit integer stored at byte index k of bv,\n" +
        "  an exact integer in [-32768, 32767]. The 2 bytes at k must lie within bv;\n" +
        "  endianness is the symbol big or little.\n" +
        "Example:\n" +
        "  (bytevector-s16-ref #u8(255 255) 0 'big) => -1";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        byte[] bv = Value.AsBytevector(arguments[0]);
        int k = BytevectorNumbers.Index(pos, Name(), bv, arguments[1], 2);
        bool little = BytevectorNumbers.Little(pos, Name(), arguments[2]);
        return BytevectorNumbers.ReadS(bv, k, 2, little);
    }
}
