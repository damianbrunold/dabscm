namespace scheme;

public class PrimitiveBytevectorU16Ref : Primitive
{
    public override string Name() => "bytevector-u16-ref";
    public override string Info() =>
        "Syntax: (bytevector-u16-ref bv k endianness)\n" +
        "Library: (scm bytevector)\n" +
        "Description: Returns the unsigned 16-bit integer stored at byte index k of bv,\n" +
        "  an exact integer in [0, 65535]. The 2 bytes at k must lie within bv;\n" +
        "  endianness is the symbol big or little.\n" +
        "Example:\n" +
        "  (bytevector-u16-ref #u8(1 2) 0 'little) => 513";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        byte[] bv = Value.AsBytevector(arguments[0]);
        int k = BytevectorNumbers.Index(pos, Name(), bv, arguments[1], 2);
        bool little = BytevectorNumbers.Little(pos, Name(), arguments[2]);
        return (long)BytevectorNumbers.ReadU(bv, k, 2, little);
    }
}
