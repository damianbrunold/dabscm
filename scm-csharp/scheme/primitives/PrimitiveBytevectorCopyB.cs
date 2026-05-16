namespace scheme;

public class PrimitiveBytevectorCopyB : Primitive
{
    public override string Name() => "bytevector-copy!";
    public override string Info() =>
        "Syntax: (bytevector-copy! to at from) (bytevector-copy! to at from start) (bytevector-copy! to at from start end)\n" +
        "Library: (scheme base)\n" +
        "Description: Copies bytes from bytevector from (from start to end) into bytevector to starting at at. It is an error if this would overwrite to's bounds.\n" +
        "Example:\n" +
        "  (let ((bv (bytevector 1 2 3 4 5)))\n" +
        "    (bytevector-copy! bv 1 #u8(10 11) 0 2)\n" +
        "    bv) => #u8(1 10 11 4 5)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 5);
        byte[] to = Value.AsBytevector(arguments[0]);
        int at = IntegerMath.ToInt(arguments[1]);
        byte[] from = Value.AsBytevector(arguments[2]);
        int start = arguments.Length >= 4 ? IntegerMath.ToInt(arguments[3]) : 0;
        int end = arguments.Length >= 5 ? IntegerMath.ToInt(arguments[4]) : from.Length;
        if (start < 0 || end > from.Length || start > end)
            throw new SchemeError(pos, "bytevector-copy!: invalid source range");
        if (at < 0 || at + (end - start) > to.Length)
            throw new SchemeError(pos, "bytevector-copy!: destination out of range");
        Array.Copy(from, start, to, at, end - start);
        return new Values();
    }
}
