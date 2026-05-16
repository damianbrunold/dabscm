namespace scheme;

public class PrimitiveModulo : Primitive
{
    public override string Name()
    {
        return "modulo";
    }

    public override string Info()
    {
        return
            "Syntax: (modulo n1 n2)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the integer modulus of n1 divided by n2. The result has the same sign as n2.\n" +
            "Example:\n" +
            "  (modulo 13 4) => 1\n" +
            "  (modulo -13 4) => 3\n" +
            "  (modulo 13 -4) => -3";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        if (AllIntegers(arguments))
        {
            return IntegerMath.GenericModulo(arguments[0], arguments[1]);
        }
        else
        {
            double a = ToReal(arguments[0]);
            double b = ToReal(arguments[1]);
            double r = a % b;
            if ((r >= 0) != (b >= 0))
            {
                return r + b;
            }
            return r;
        }
    }
}
