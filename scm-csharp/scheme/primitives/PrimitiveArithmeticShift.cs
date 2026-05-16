namespace scheme;

public class PrimitiveArithmeticShift : Primitive
{
    public override string Name()
    {
        return "arithmetic-shift";
    }

    public override string Info()
    {
        return
            "Syntax: (arithmetic-shift i count)\n" +
            "Library: (srfi 151)\n" +
            "Description: Returns i shifted left by count bits if count is positive, or\n" +
            "right by -count bits if count is negative. Right shifts are arithmetic\n" +
            "(sign-preserving).\n" +
            "Example:\n" +
            "  (arithmetic-shift 8 2) => 32\n" +
            "  (arithmetic-shift 32 -2) => 8\n" +
            "  (arithmetic-shift -1 -1) => -1";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        long count = IntegerMath.ToLong(arguments[1]);
        return IntegerMath.ArithmeticShift(arguments[0], count);
    }
}
