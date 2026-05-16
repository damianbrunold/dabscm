namespace scheme;

public class PrimitiveQuotient : Primitive
{
    public override string Name()
    {
        return "quotient";
    }

    public override string Info()
    {
        return
            "Syntax: (quotient n1 n2)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the integer quotient of n1 and n2. The result is exact if both arguments are exact, and is otherwise inexact. It is an error if n2 is zero.\n" +
            "Example:\n" +
            "  (quotient 13 4) => 3\n" +
            "  (quotient -13 4) => -3\n" +
            "  (quotient 13 -4) => -3";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        if (AllIntegers(arguments))
        {
            return IntegerMath.GenericQuotient(arguments[0], arguments[1]);
        }
        else
        {
            return (double) ((long) (ToReal(arguments[0]) / ToReal(arguments[1])));
        }
    }
}
