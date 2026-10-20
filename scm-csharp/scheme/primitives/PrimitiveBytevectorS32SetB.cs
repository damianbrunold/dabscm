namespace scheme;

public class PrimitiveBytevectorS32SetB : Primitive
{
    public override string Name() => "bytevector-s32-set!";
    public override string Info() =>
        "Syntax: (bytevector-s32-set! bv k n endianness)\n" +
        "Library: (scm bytevector)\n" +
        "Description: Stores the exact integer n, which must be in [-2147483648, 2147483647], as\n" +
        "  an signed 32-bit integer at byte index k of bv. The 4 bytes at k must lie\n" +
        "  within bv; endianness is the symbol big or little.\n" +
        "Example:\n" +
        "  (let ((bv (make-bytevector 4 0))) (bytevector-s32-set! bv 0 -1 'big) bv) => #u8(255 255 255 255)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 4, 4);
        byte[] bv = Value.AsBytevector(arguments[0]);
        int k = BytevectorNumbers.Index(pos, Name(), bv, arguments[1], 4);
        bool little = BytevectorNumbers.Little(pos, Name(), arguments[3]);
        BytevectorNumbers.WriteInt(pos, Name(), bv, k, 4, true, arguments[2], little);
        return new Values();
    }
}
