namespace scheme;

public class PrimitiveComplexP : Primitive
{
    public override string Name()
    {
        return "complex?";
    }

    public override string Info()
    {
        return
            "Syntax: (complex? obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is a complex number, #f otherwise.\n" +
            "  In the R7RS numeric tower, all numbers are complex.\n" +
            "Example:\n" +
            "  (complex? 3+4i) => #t\n" +
            "  (complex? 3)    => #t";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        object obj = arguments[0];
        return Value.IsComplex(obj) || Value.IsReal(obj) || Value.IsInteger(obj) || Value.IsRational(obj)
            ? Value.T : Value.F;
    }
}
