namespace scheme;

public class PrimitiveBytevectorIeeeDoubleSetB : Primitive
{
    public override string Name() => "bytevector-ieee-double-set!";
    public override string Info() =>
        "Syntax: (bytevector-ieee-double-set! bv k n endianness)\n" +
        "Library: (scm bytevector)\n" +
        "Description: Stores the exact integer n, which must be None, as\n" +
        "  an IEEE 754 double-precision float at byte index k of bv. The 8 bytes at k must lie\n" +
        "  within bv; endianness is the symbol big or little.\n" +
        "Example:\n" +
        "  (let ((bv (make-bytevector 8 0))) (bytevector-ieee-double-set! bv 0 1.0 'big) bv) => #u8(63 240 0 0 0 0 0 0)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 4, 4);
        byte[] bv = Value.AsBytevector(arguments[0]);
        int k = BytevectorNumbers.Index(pos, Name(), bv, arguments[1], 8);
        bool little = BytevectorNumbers.Little(pos, Name(), arguments[3]);
        BytevectorNumbers.WriteDouble(bv, k, ToReal(arguments[2]), little);
        return new Values();
    }
}
