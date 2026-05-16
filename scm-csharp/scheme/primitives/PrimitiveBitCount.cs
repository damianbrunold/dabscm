namespace scheme;

public class PrimitiveBitCount : Primitive
{
    public override string Name()
    {
        return "bit-count";
    }

    public override string Info()
    {
        return
            "Syntax: (bit-count i)\n" +
            "Library: (srfi 151)\n" +
            "Description: Returns the population count of i: the number of 1-bits for\n" +
            "non-negative i, or the number of 0-bits for negative i.\n" +
            "Example:\n" +
            "  (bit-count 10) => 2\n" +
            "  (bit-count -11) => 2\n" +
            "  (bit-count 0) => 0";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return IntegerMath.BitCount(arguments[0]);
    }
}
