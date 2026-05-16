namespace scheme;

public class PrimitiveOpenInputBytevector : Primitive
{
    public override string Name() => "open-input-bytevector";
    public override string Info() =>
        "Syntax: (open-input-bytevector bv)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns a binary input port that reads bytes from the bytevector bv.\n" +
        "Example:\n" +
        "  (let ((p (open-input-bytevector #u8(1 2 3))))\n" +
        "    (read-u8 p)) => 1";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        byte[] bv = Value.AsBytevector(arguments[0]);
        return new BinaryInputStream(new MemoryStream(bv));
    }
}
