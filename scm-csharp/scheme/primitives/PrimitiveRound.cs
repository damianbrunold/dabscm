namespace scheme;

public class PrimitiveRound : Primitive
{
    public override string Name()
    {
        return "round";
    }

    public override string Info()
    {
        return
            "Syntax: (round z)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the integer closest to z. If z is halfway between two integers, rounds to the even one (banker's rounding).\n" +
            "Example:\n" +
            "  (round 3.5) => 4.0\n" +
            "  (round 2.5) => 2.0\n" +
            "  (round 7/2) => 4";
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
            return (long)Math.Round(Value.AsRational(arguments[0]).ToDouble(), MidpointRounding.ToEven);
        }
        else
        {
            return Math.Round(ToReal(arguments[0]));
        }
    }
}
