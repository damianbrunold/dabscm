namespace scheme;

public class PrimitiveAtan : Primitive
{
    public override string Name()
    {
        return "atan";
    }

    public override string Info()
    {
        return
            "Syntax: (atan z) (atan y x)\n" +
            "Library: (scheme inexact)\n" +
            "Description: Returns the arc tangent of z, or of y/x when two arguments are given. The result is in radians.\n" +
            "Example:\n" +
            "  (atan 0.0) => 0.0\n" +
            "  (atan 1.0 1.0) => 0.7853981633974483";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        if (arguments.Length == 1) return Math.Atan(ToReal(arguments[0]));
        else return Math.Atan2(ToReal(arguments[0]), ToReal(arguments[1]));
    }
}
