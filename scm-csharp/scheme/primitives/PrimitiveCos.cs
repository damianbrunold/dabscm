namespace scheme;

public class PrimitiveCos : Primitive
{
    public override string Name()
    {
        return "cos";
    }

    public override string Info()
    {
        return
            "Syntax: (cos z)\n" +
            "Library: (scheme inexact)\n" +
            "Description: Returns the cosine of z. The argument is in radians.\n" +
            "Example:\n" +
            "  (cos 0.0) => 1.0\n" +
            "  (cos 3.141592653589793) => -1.0";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Math.Cos(ToReal(arguments[0]));
    }
}
