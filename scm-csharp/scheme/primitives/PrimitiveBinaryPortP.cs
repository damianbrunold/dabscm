namespace scheme;

public class PrimitiveBinaryPortP : Primitive
{
    public override string Name() => "binary-port?";
    public override string Info() =>
        "Syntax: (binary-port? obj)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns #t if obj is a binary port, otherwise returns #f.\n" +
        "Example:\n" +
        "  (binary-port? (open-input-bytevector #u8(1 2 3))) => #t\n" +
        "  (binary-port? (open-input-string \"abc\")) => #f";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsBinaryInputPort(arguments[0]) || Value.IsBinaryOutputPort(arguments[0]);
    }
}
