namespace scheme;

public class PrimitiveBytevectorS32Ref : Primitive
{
    public override string Name() => "bytevector-s32-ref";
    public override string Info() =>
        "Syntax: (bytevector-s32-ref bv k endianness)\n" +
        "Library: (scm bytevector)\n" +
        "Description: Returns the signed 32-bit integer stored at byte index k of bv,\n" +
        "  an exact integer in [-2147483648, 2147483647]. The 4 bytes at k must lie within bv;\n" +
        "  endianness is the symbol big or little.\n" +
        "Example:\n" +
        "  (bytevector-s32-ref #u8(255 255 255 255) 0 'little) => -1";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        byte[] bv = Value.AsBytevector(arguments[0]);
        int k = BytevectorNumbers.Index(pos, Name(), bv, arguments[1], 4);
        bool little = BytevectorNumbers.Little(pos, Name(), arguments[2]);
        return BytevectorNumbers.ReadS(bv, k, 4, little);
    }
}
