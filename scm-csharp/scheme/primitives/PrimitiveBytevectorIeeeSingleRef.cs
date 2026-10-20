namespace scheme;

public class PrimitiveBytevectorIeeeSingleRef : Primitive
{
    public override string Name() => "bytevector-ieee-single-ref";
    public override string Info() =>
        "Syntax: (bytevector-ieee-single-ref bv k endianness)\n" +
        "Library: (scm bytevector)\n" +
        "Description: Returns the IEEE 754 single-precision float stored at byte index k of bv,\n" +
        "  as an inexact real. The 4 bytes at k must lie within bv;\n" +
        "  endianness is the symbol big or little.\n" +
        "Example:\n" +
        "  (bytevector-ieee-single-ref #u8(0 0 128 63) 0 'little) => 1.0";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        byte[] bv = Value.AsBytevector(arguments[0]);
        int k = BytevectorNumbers.Index(pos, Name(), bv, arguments[1], 4);
        bool little = BytevectorNumbers.Little(pos, Name(), arguments[2]);
        return (double)BytevectorNumbers.ReadSingle(bv, k, little);
    }
}
