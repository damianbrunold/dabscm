namespace scheme;

public class PrimitiveGetOutputBytevector : Primitive
{
    public override string Name() => "get-output-bytevector";
    public override string Info() =>
        "Syntax: (get-output-bytevector port)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns a bytevector consisting of the bytes that have been output to the given bytevector output port (created with open-output-bytevector).\n" +
        "Example:\n" +
        "  (let ((p (open-output-bytevector)))\n" +
        "    (write-u8 65 p)\n" +
        "    (get-output-bytevector p)) => #u8(65)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.AsBinaryOutputPort(arguments[0]).GetBytes();
    }
}
