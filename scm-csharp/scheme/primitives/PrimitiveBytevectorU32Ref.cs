namespace scheme;

public class PrimitiveBytevectorU32Ref : Primitive
{
    public override string Name() => "bytevector-u32-ref";
    public override string Info() =>
        "Syntax: (bytevector-u32-ref bv k endianness)\n" +
        "Library: (scm bytevector)\n" +
        "Description: Returns the unsigned 32-bit integer stored at byte index k of bv,\n" +
        "  an exact integer in [0, 4294967295]. The 4 bytes at k must lie within bv;\n" +
        "  endianness is the symbol big or little.\n" +
        "Example:\n" +
        "  (bytevector-u32-ref #u8(0 0 1 0) 0 'big) => 256";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        byte[] bv = Value.AsBytevector(arguments[0]);
        int k = BytevectorNumbers.Index(pos, Name(), bv, arguments[1], 4);
        bool little = BytevectorNumbers.Little(pos, Name(), arguments[2]);
        return (long)BytevectorNumbers.ReadU(bv, k, 4, little);
    }
}
