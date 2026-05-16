namespace scheme;

public class PrimitiveBytevectorU8Ref : Primitive
{
    public override string Name() => "bytevector-u8-ref";
    public override string Info() =>
        "Syntax: (bytevector-u8-ref bv k)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns the byte at index k of bytevector bv as an exact integer in [0, 255].\n" +
        "Example:\n" +
        "  (bytevector-u8-ref #u8(1 2 3) 0) => 1\n" +
        "  (bytevector-u8-ref #u8(10 20 30) 2) => 30";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        byte[] bv = Value.AsBytevector(arguments[0]);
        long k = IntegerMath.ToLong(arguments[1]);
        if (k < 0 || k >= bv.Length) throw new SchemeError(pos, "bytevector-u8-ref: index out of range: ~s", k);
        return (long)(bv[k] & 0xFF);
    }
}
