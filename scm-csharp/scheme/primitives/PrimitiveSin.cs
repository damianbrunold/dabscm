namespace scheme;

public class PrimitiveSin : Primitive
{
    public override string Name()
    {
        return "sin";
    }

    public override string Info()
    {
        return
            "Syntax: (sin z)\n" +
            "Library: (scheme inexact)\n" +
            "Description: Returns the sine of z, where z is in radians. Returns an inexact result.\n" +
            "Example:\n" +
            "  (sin 0) => 0.0\n" +
            "  (sin (/ (acos -1) 2)) => 1.0";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Math.Sin(ToReal(arguments[0]));
    }
}
