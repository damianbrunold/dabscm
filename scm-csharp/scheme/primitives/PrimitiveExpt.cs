namespace scheme;

public class PrimitiveExpt : Primitive
{
    public override string Name()
    {
        return "expt";
    }

    public override string Info()
    {
        return
            "Syntax: (expt z1 z2)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns z1 raised to the power z2. If z2 is exact 0, returns exact 1.\n" +
            "Example:\n" +
            "  (expt 2 10) => 1024\n" +
            "  (expt 4 0) => 1\n" +
            "  (expt 2.0 3) => 8.0";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        if (AllIntegers(arguments))
        {
            long b = IntegerMath.ToLong(arguments[1]);
            if (b == 0) return 1L;
            if (b > 0) {
                return IntegerMath.Expt(arguments[0], b);
            } else {
                return Rational.Div(1L, IntegerMath.Expt(arguments[0], -b));
            }
        }
        else
        {
            double a = ToReal(arguments[0]);
            double b = ToReal(arguments[1]);
            if (b == 0.0) return 1.0;
            return Math.Pow(a, b);
        }
    }
}
