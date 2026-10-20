namespace scheme;

public class PrimitiveBytevectorS16SetB : Primitive
{
    public override string Name() => "bytevector-s16-set!";
    public override string Info() =>
        "Syntax: (bytevector-s16-set! bv k n endianness)\n" +
        "Library: (scm bytevector)\n" +
        "Description: Stores the exact integer n, which must be in [-32768, 32767], as\n" +
        "  an signed 16-bit integer at byte index k of bv. The 2 bytes at k must lie\n" +
        "  within bv; endianness is the symbol big or little.\n" +
        "Example:\n" +
        "  (let ((bv (make-bytevector 2 0))) (bytevector-s16-set! bv 0 -2 'little) bv) => #u8(254 255)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 4, 4);
        byte[] bv = Value.AsBytevector(arguments[0]);
        int k = BytevectorNumbers.Index(pos, Name(), bv, arguments[1], 2);
        bool little = BytevectorNumbers.Little(pos, Name(), arguments[3]);
        BytevectorNumbers.WriteInt(pos, Name(), bv, k, 2, true, arguments[2], little);
        return new Values();
    }
}
