namespace scheme;

public class PrimitiveTan : Primitive
{
    public override string Name()
    {
        return "tan";
    }

    public override string Info()
    {
        return
            "Syntax: (tan z)\n" +
            "Library: (scheme inexact)\n" +
            "Description: Returns the trigonometric tangent of z, where z is in radians.\n" +
            "Example:\n" +
            "  (tan 0) => 0.0\n" +
            "  (tan (/ (* 3.14159265 1) 4)) => 1.0";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Math.Tan(ToReal(arguments[0]));
    }
}
