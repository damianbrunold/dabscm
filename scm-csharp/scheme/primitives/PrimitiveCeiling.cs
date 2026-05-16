namespace scheme;

public class PrimitiveCeiling : Primitive
{
    public override string Name()
    {
        return "ceiling";
    }

    public override string Info()
    {
        return
            "Syntax: (ceiling z)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the smallest integer not smaller than z (rounds toward positive infinity).\n" +
            "Example:\n" +
            "  (ceiling 1.2) => 2.0\n" +
            "  (ceiling -1.2) => -1.0\n" +
            "  (ceiling 3) => 3";
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
            return (long)Math.Ceiling(Value.AsRational(arguments[0]).ToDouble());
        }
        else
        {
            return Math.Ceiling(ToReal(arguments[0]));
        }
    }
}
