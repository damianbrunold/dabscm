namespace scheme;

public class PrimitiveBase64Decode : Primitive
{
    public override string Name() => "base64-decode";

    public override string Info() =>
        "Syntax: (base64-decode string)\n" +
        "Library: (scm crypto)\n" +
        "Description: Decodes a base64-encoded string and returns a bytevector.\n" +
        "Example:\n" +
        "  (base64-decode \"SGVsbG8=\") => #u8(72 101 108 108 111)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        string s = new String(Value.AsString(arguments[0]));
        return Convert.FromBase64String(s);
    }
}
