namespace scheme;

public class PrimitiveBase64Encode : Primitive
{
    public override string Name() => "base64-encode";

    public override string Info() =>
        "Syntax: (base64-encode bytevector)\n" +
        "Library: (scm crypto)\n" +
        "Description: Returns the base64-encoded string of a bytevector.\n" +
        "Example:\n" +
        "  (base64-encode #u8(72 101 108 108 111)) => \"SGVsbG8=\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        byte[] bv = Value.AsBytevector(arguments[0]);
        return Convert.ToBase64String(bv).ToCharArray();
    }
}
