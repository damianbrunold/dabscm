namespace scheme;

public class PrimitiveExactP : Primitive
{
    public override string Name()
    {
        return "exact?";
    }

    public override string Info()
    {
        return
            "Syntax: (exact? z)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if z is an exact number (integer or rational), otherwise returns #f.\n" +
            "Example:\n" +
            "  (exact? 1) => #t\n" +
            "  (exact? 1.0) => #f\n" +
            "  (exact? 1/3) => #t";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsComplex(arguments[0]))
        {
            Complex c = Value.AsComplex(arguments[0]);
            return Complex.IsExact(c.Real) && Complex.IsExact(c.Imag);
        }
        return Value.IsInteger(arguments[0]) || Value.IsRational(arguments[0]);
    }
}
