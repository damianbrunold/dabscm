namespace scheme;

public class PrimitiveBytevectorIeeeDoubleRef : Primitive
{
    public override string Name() => "bytevector-ieee-double-ref";
    public override string Info() =>
        "Syntax: (bytevector-ieee-double-ref bv k endianness)\n" +
        "Library: (scm bytevector)\n" +
        "Description: Returns the IEEE 754 double-precision float stored at byte index k of bv,\n" +
        "  an exact integer None. The 8 bytes at k must lie within bv;\n" +
        "  endianness is the symbol big or little.\n" +
        "Example:\n" +
        "  (bytevector-ieee-double-ref #u8(0 0 0 0 0 0 240 63) 0 'little) => 1.0";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        byte[] bv = Value.AsBytevector(arguments[0]);
        int k = BytevectorNumbers.Index(pos, Name(), bv, arguments[1], 8);
        bool little = BytevectorNumbers.Little(pos, Name(), arguments[2]);
        return BytevectorNumbers.ReadDouble(bv, k, little);
    }
}
