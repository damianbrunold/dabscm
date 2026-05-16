namespace scheme;

public class PrimitiveInexact : Primitive
{
    public override string Name()
    {
        return "inexact";
    }

    public override string Info()
    {
        return
            "Syntax: (inexact z)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the inexact (floating-point) number that is numerically closest to z.\n" +
            "Example:\n" +
            "  (inexact 1) => 1.0\n" +
            "  (inexact 1/3) => 0.3333333333333333";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsComplex(arguments[0]))
        {
            Complex c = Value.AsComplex(arguments[0]);
            return Complex.Create(Complex.ToInexact(c.Real), Complex.ToInexact(c.Imag));
        }
        if (Value.IsReal(arguments[0])) return arguments[0];
        if (Value.IsRational(arguments[0])) return Value.AsRational(arguments[0]).ToDouble();
        if (Value.IsBigInteger(arguments[0])) return IntegerMath.ToDouble(arguments[0]);
        return (double)Value.AsInteger(arguments[0]);
    }
}
