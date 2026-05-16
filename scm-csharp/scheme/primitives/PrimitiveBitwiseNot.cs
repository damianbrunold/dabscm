namespace scheme;

public class PrimitiveBitwiseNot : Primitive
{
    public override string Name()
    {
        return "bitwise-not";
    }

    public override string Info()
    {
        return
            "Syntax: (bitwise-not i)\n" +
            "Library: (srfi 151)\n" +
            "Description: Returns the bitwise complement of i.\n" +
            "Example:\n" +
            "  (bitwise-not 10) => -11\n" +
            "  (bitwise-not -1) => 0\n" +
            "  (bitwise-not 0) => -1";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return IntegerMath.BitwiseNot(arguments[0]);
    }
}
