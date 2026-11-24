namespace scheme;

public class PrimitiveSqrt : Primitive
{
    public override string Name()
    {
        return "sqrt";
    }

    public override string Info()
    {
        return
            "Syntax: (sqrt z)\n" +
            "Library: (scheme inexact)\n" +
            "Description: Returns the principal square root of z. Returns an exact integer when the result is an exact integer, otherwise returns an inexact number.\n" +
            "Example:\n" +
            "  (sqrt 4) => 2\n" +
            "  (sqrt 2) => 1.4142135623730951\n" +
            "  (sqrt 9) => 3";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return ComplexMath.Sqrt(arguments[0]);
    }
}
