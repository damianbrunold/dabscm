namespace scheme;

public class PrimitiveRemainder : Primitive
{
    public override string Name()
    {
        return "remainder";
    }

    public override string Info()
    {
        return
            "Syntax: (remainder n1 n2)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the remainder of dividing n1 by n2. The result has the same sign as n1. It is an error if n2 is zero.\n" +
            "Example:\n" +
            "  (remainder 13 4) => 1\n" +
            "  (remainder -13 4) => -1\n" +
            "  (remainder 13 -4) => 1";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        if (AllIntegers(arguments))
        {
            return IntegerMath.GenericRemainder(arguments[0], arguments[1]);
        }
        else
        {
            return (double) ((long) (ToReal(arguments[0]) % ToReal(arguments[1])));
        }
    }
}
