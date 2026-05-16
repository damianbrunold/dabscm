namespace scheme;

public class PrimitiveIntegerLength : Primitive
{
    public override string Name()
    {
        return "integer-length";
    }

    public override string Info()
    {
        return
            "Syntax: (integer-length i)\n" +
            "Library: (srfi 151)\n" +
            "Description: Returns the number of bits needed to represent i, not counting\n" +
            "the sign bit. For non-negative i, this is the index of the highest set bit\n" +
            "plus one. For negative i, it is the number of bits in (bitwise-not i).\n" +
            "Example:\n" +
            "  (integer-length 0) => 0\n" +
            "  (integer-length 1) => 1\n" +
            "  (integer-length 7) => 3\n" +
            "  (integer-length -1) => 0\n" +
            "  (integer-length -8) => 3";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return IntegerMath.IntegerLength(arguments[0]);
    }
}
