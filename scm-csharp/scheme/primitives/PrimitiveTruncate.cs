namespace scheme;

public class PrimitiveTruncate : Primitive
{
    public override string Name()
    {
        return "truncate";
    }

    public override string Info()
    {
        return
            "Syntax: (truncate x)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the integer closest to x whose absolute value is not larger than the absolute value of x (rounds toward zero).\n" +
            "Example:\n" +
            "  (truncate 3.7) => 3.0\n" +
            "  (truncate -3.7) => -3.0";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsInteger(arguments[0]))
        {
            return arguments[0];
        }
        else if (Value.IsRational(arguments[0]))
        {
            return (long)Math.Truncate(Value.AsRational(arguments[0]).ToDouble());
        }
        else
        {
            return Math.Truncate(ToReal(arguments[0]));
        }
    }
}
