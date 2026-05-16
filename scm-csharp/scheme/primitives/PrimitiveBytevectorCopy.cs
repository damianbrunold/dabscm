namespace scheme;

public class PrimitiveBytevectorCopy : Primitive
{
    public override string Name() => "bytevector-copy";
    public override string Info() =>
        "Syntax: (bytevector-copy bv) (bytevector-copy bv start) (bytevector-copy bv start end)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns a newly allocated copy of the elements of bv from start (inclusive) to end (exclusive).\n" +
        "Example:\n" +
        "  (bytevector-copy #u8(1 2 3)) => #u8(1 2 3)\n" +
        "  (bytevector-copy #u8(1 2 3) 1 2) => #u8(2)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        byte[] bv = Value.AsBytevector(arguments[0]);
        int start = arguments.Length >= 2 ? IntegerMath.ToInt(arguments[1]) : 0;
        int end = arguments.Length >= 3 ? IntegerMath.ToInt(arguments[2]) : bv.Length;
        if (start < 0 || end > bv.Length || start > end)
            throw new SchemeError(pos, "bytevector-copy: invalid range ~s ~s", start, end);
        byte[] result = new byte[end - start];
        Array.Copy(bv, start, result, 0, end - start);
        return result;
    }
}
