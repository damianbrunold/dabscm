namespace scheme;

public class PrimitiveBytevectorU8SetB : Primitive
{
    public override string Name() => "bytevector-u8-set!";
    public override string Info() =>
        "Syntax: (bytevector-u8-set! bv k byte)\n" +
        "Library: (scheme base)\n" +
        "Description: Stores byte (an exact integer in [0, 255]) into element k of bytevector bv.\n" +
        "Example:\n" +
        "  (let ((bv (bytevector 1 2 3)))\n" +
        "    (bytevector-u8-set! bv 1 42)\n" +
        "    bv) => #u8(1 42 3)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        byte[] bv = Value.AsBytevector(arguments[0]);
        long k = IntegerMath.ToLong(arguments[1]);
        long v = IntegerMath.ToLong(arguments[2]);
        if (k < 0 || k >= bv.Length) throw new SchemeError(pos, "bytevector-u8-set!: index out of range: ~s", k);
        if (v < 0 || v > 255) throw new SchemeError(pos, "bytevector-u8-set!: byte out of range: ~s", v);
        bv[k] = (byte)v;
        return new Values();
    }
}
