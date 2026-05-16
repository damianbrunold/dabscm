namespace scheme;

public class PrimitiveBytevectorLength : Primitive
{
    public override string Name() => "bytevector-length";
    public override string Info() =>
        "Syntax: (bytevector-length bv)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns the number of bytes in the given bytevector.\n" +
        "Example:\n" +
        "  (bytevector-length #u8(1 2 3)) => 3";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return (long)Value.AsBytevector(arguments[0]).Length;
    }
}
