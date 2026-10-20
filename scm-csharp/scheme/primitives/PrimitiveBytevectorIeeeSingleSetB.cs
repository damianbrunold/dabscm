namespace scheme;

public class PrimitiveBytevectorIeeeSingleSetB : Primitive
{
    public override string Name() => "bytevector-ieee-single-set!";
    public override string Info() =>
        "Syntax: (bytevector-ieee-single-set! bv k x endianness)\n" +
        "Library: (scm bytevector)\n" +
        "Description: Stores the real x as an IEEE 754 single-precision float at byte index k of bv\n" +
        "  (rounded to the nearest representable value). The 4 bytes at k\n" +
        "  must lie within bv; endianness is the symbol big or little.\n" +
        "Example:\n" +
        "  (let ((bv (make-bytevector 4 0))) (bytevector-ieee-single-set! bv 0 1.0 'big) bv) => #u8(63 128 0 0)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 4, 4);
        byte[] bv = Value.AsBytevector(arguments[0]);
        int k = BytevectorNumbers.Index(pos, Name(), bv, arguments[1], 4);
        bool little = BytevectorNumbers.Little(pos, Name(), arguments[3]);
        BytevectorNumbers.WriteSingle(bv, k, (float)ToReal(arguments[2]), little);
        return new Values();
    }
}
