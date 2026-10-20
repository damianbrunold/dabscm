namespace scheme;

public class PrimitiveBytevectorU16SetB : Primitive
{
    public override string Name() => "bytevector-u16-set!";
    public override string Info() =>
        "Syntax: (bytevector-u16-set! bv k n endianness)\n" +
        "Library: (scm bytevector)\n" +
        "Description: Stores the exact integer n, which must be in [0, 65535], as\n" +
        "  an unsigned 16-bit integer at byte index k of bv. The 2 bytes at k must lie\n" +
        "  within bv; endianness is the symbol big or little.\n" +
        "Example:\n" +
        "  (let ((bv (make-bytevector 2 0))) (bytevector-u16-set! bv 0 513 'big) bv) => #u8(2 1)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 4, 4);
        byte[] bv = Value.AsBytevector(arguments[0]);
        int k = BytevectorNumbers.Index(pos, Name(), bv, arguments[1], 2);
        bool little = BytevectorNumbers.Little(pos, Name(), arguments[3]);
        BytevectorNumbers.WriteInt(pos, Name(), bv, k, 2, false, arguments[2], little);
        return new Values();
    }
}
