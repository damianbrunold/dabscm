namespace scheme;

public class PrimitiveIntegerP : Primitive
{
    public override string Name()
    {
        return "integer?";
    }

    public override string Info()
    {
        return
            "Syntax: (integer? obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is an integer (exact or inexact with an integer value), otherwise returns #f.\n" +
            "Example:\n" +
            "  (integer? 1) => #t\n" +
            "  (integer? 1.0) => #t\n" +
            "  (integer? 1.5) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsInteger(arguments[0])) return Value.T;
        if (Value.IsReal(arguments[0]))
        {
            double val = ToReal(arguments[0]);
            return (Double.IsFinite(val) && val == Math.Truncate(val)) ? Value.T : Value.F;
        }
        return Value.F;
    }
}
