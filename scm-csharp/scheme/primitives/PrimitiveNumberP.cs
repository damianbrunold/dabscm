namespace scheme;

public class PrimitiveNumberP : Primitive
{
    public override string Name()
    {
        return "number?";
    }

    public override string Info()
    {
        return
            "Syntax: (number? obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is a number (exact integer, rational, or inexact real), otherwise returns #f.\n" +
            "Example:\n" +
            "  (number? 3) => #t\n" +
            "  (number? 3.5) => #t\n" +
            "  (number? \"3\") => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsReal(arguments[0]) || Value.IsInteger(arguments[0]) || Value.IsRational(arguments[0]) || Value.IsComplex(arguments[0]);
    }
}
