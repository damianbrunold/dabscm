namespace scheme;

public class PrimitiveFloor : Primitive
{
    public override string Name()
    {
        return "floor";
    }

    public override string Info()
    {
        return
            "Syntax: (floor z)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the largest integer not larger than z (rounds toward negative infinity).\n" +
            "Example:\n" +
            "  (floor 1.8) => 1.0\n" +
            "  (floor -1.2) => -2.0\n" +
            "  (floor 3) => 3";
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
            return (long)Math.Floor(Value.AsRational(arguments[0]).ToDouble());
        }
        else
        {
            return Math.Floor(ToReal(arguments[0]));
        }
    }
}
