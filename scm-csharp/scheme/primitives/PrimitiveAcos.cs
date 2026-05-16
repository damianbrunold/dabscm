namespace scheme;

public class PrimitiveAcos : Primitive
{
    public override string Name()
    {
        return "acos";
    }

    public override string Info()
    {
        return
            "Syntax: (acos z)\n" +
            "Library: (scheme inexact)\n" +
            "Description: Returns the arc cosine of z. The result is in radians.\n" +
            "Example:\n" +
            "  (acos 1.0) => 0.0\n" +
            "  (acos 0.0) => 1.5707963267948966";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Math.Acos(ToReal(arguments[0]));
    }
}
