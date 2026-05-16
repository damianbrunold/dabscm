namespace scheme;

public class PrimitiveSqrt : Primitive
{
    public override string Name()
    {
        return "sqrt";
    }

    public override string Info()
    {
        return
            "Syntax: (sqrt z)\n" +
            "Library: (scheme inexact)\n" +
            "Description: Returns the principal square root of z. Returns an exact integer when the result is an exact integer, otherwise returns an inexact number.\n" +
            "Example:\n" +
            "  (sqrt 4) => 2\n" +
            "  (sqrt 2) => 1.4142135623730951\n" +
            "  (sqrt 9) => 3";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsInteger(arguments[0]) || Value.IsRational(arguments[0]))
        {
            double val = ToReal(arguments[0]);
            if (val < 0) return Complex.Create(0L, Math.Sqrt(-val));
            double result = Math.Sqrt(val);
            if (Value.IsInteger(arguments[0]) && result == (double)((long)result)) return (long)result;
            return result;
        }
        if (arguments[0] is double d)
        {
            if (d < 0) return Complex.Create(0.0, Math.Sqrt(-d));
            return Math.Sqrt(d);
        }
        if (arguments[0] is Complex c)
        {
            // sqrt(a + bi) = sqrt((|z|+a)/2) + sign(b)*sqrt((|z|-a)/2)*i
            double a = Complex.PartToDouble(c.Real);
            double b = Complex.PartToDouble(c.Imag);
            double mag = Math.Sqrt(a * a + b * b);
            double realPart = Math.Sqrt((mag + a) / 2.0);
            double imagPart = (b >= 0 ? 1 : -1) * Math.Sqrt((mag - a) / 2.0);
            return Complex.Create(realPart, imagPart);
        }
        double r = Math.Sqrt(ToReal(arguments[0]));
        return r;
    }
}
