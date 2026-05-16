namespace scheme;

public class PrimitiveOpenOutputBytevector : Primitive
{
    public override string Name() => "open-output-bytevector";
    public override string Info() =>
        "Syntax: (open-output-bytevector)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns a binary output port that accumulates bytes in memory. Use get-output-bytevector to retrieve the accumulated bytes.\n" +
        "Example:\n" +
        "  (let ((p (open-output-bytevector)))\n" +
        "    (write-u8 65 p)\n" +
        "    (get-output-bytevector p)) => #u8(65)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        return new BinaryOutputStream(new MemoryStream(), isBytevectorPort: true);
    }
}
