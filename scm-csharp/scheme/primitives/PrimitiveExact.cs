namespace scheme;

public class PrimitiveExact : Primitive
{
    public override string Name()
    {
        return "exact";
    }

    public override string Info()
    {
        return
            "Syntax: (exact z)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the exact number that is numerically equal to z.\n" +
            "  For an inexact z that is the exact value of the binary floating-point\n" +
            "  number (R7RS), so (exact 0.1) is 3602879701896397/36028797018963968;\n" +
            "  rationalize finds the simplest rational near it.\n" +
            "Example:\n" +
            "  (exact 1.5) => 3/2\n" +
            "  (exact 0.1) => 3602879701896397/36028797018963968\n" +
            "  (exact 3.0) => 3\n" +
            "  (exact 3) => 3";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsInteger(arguments[0])) return arguments[0];
        if (Value.IsRational(arguments[0])) return arguments[0];
        if (Value.IsComplex(arguments[0]))
        {
            Complex c = Value.AsComplex(arguments[0]);
            return Complex.Create(Complex.ToExact(c.Real), Complex.ToExact(c.Imag));
        }
        double d = Value.AsReal(arguments[0]);
        if (double.IsNaN(d) || double.IsInfinity(d))
            throw new SchemeError(pos, "exact: no exact representation for ~a", arguments[0]);
        return Complex.ToExact(d);
    }
}
