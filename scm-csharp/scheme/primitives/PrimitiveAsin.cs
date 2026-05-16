namespace scheme;

public class PrimitiveAsin : Primitive
{
    public override string Name()
    {
        return "asin";
    }

    public override string Info()
    {
        return
            "Syntax: (asin z)\n" +
            "Library: (scheme inexact)\n" +
            "Description: Returns the arc sine of z. The result is in radians.\n" +
            "Example:\n" +
            "  (asin 0.0) => 0.0\n" +
            "  (asin 1.0) => 1.5707963267948966";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Math.Asin(ToReal(arguments[0]));
    }
}
