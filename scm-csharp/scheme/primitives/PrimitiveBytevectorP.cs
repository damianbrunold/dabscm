namespace scheme;

public class PrimitiveBytevectorP : Primitive
{
    public override string Name() => "bytevector?";
    public override string Info() =>
        "Syntax: (bytevector? obj)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns #t if obj is a bytevector, otherwise returns #f.\n" +
        "Example:\n" +
        "  (bytevector? #u8(1 2 3)) => #t\n" +
        "  (bytevector? \"abc\") => #f";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsBytevector(arguments[0]);
    }
}
