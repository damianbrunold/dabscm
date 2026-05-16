namespace scheme;

public class PrimitiveComplexAngle : Primitive
{
    public override string Name()
    {
        return "complex-angle";
    }

    public override string Info()
    {
        return
            "Syntax: (complex-angle z)\n" +
            "Library: (scheme complex)\n" +
            "Description: Returns the angle (argument) of the complex number z in radians.\n" +
            "Example:\n" +
            "  (complex-angle 1+1i) => 0.7853981633974483";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsComplex(arguments[0]))
            return Complex.Angle(Value.AsComplex(arguments[0]));
        throw new SchemeError(pos, "complex-angle: not a complex number: ~s", arguments[0]);
    }
}
