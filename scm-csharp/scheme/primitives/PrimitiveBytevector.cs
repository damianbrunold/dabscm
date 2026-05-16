namespace scheme;

public class PrimitiveBytevector : Primitive
{
    public override string Name() => "bytevector";
    public override string Info() =>
        "Syntax: (bytevector byte ...)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns a newly allocated bytevector containing the given byte values (each must be 0-255).\n" +
        "Example:\n" +
        "  (bytevector 1 2 3) => #u8(1 2 3)\n" +
        "  (bytevector) => #u8()";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        byte[] bv = new byte[arguments.Length];
        for (int i = 0; i < arguments.Length; i++)
        {
            long v = IntegerMath.ToLong(arguments[i]);
            if (v < 0 || v > 255) throw new SchemeError(pos, "bytevector: element out of range: ~s", v);
            bv[i] = (byte)v;
        }
        return bv;
    }
}
