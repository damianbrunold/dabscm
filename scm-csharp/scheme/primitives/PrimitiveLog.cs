namespace scheme;

public class PrimitiveLog : Primitive
{
    public override string Name()
    {
        return "log";
    }

    public override string Info()
    {
        return
            "Syntax: (log z) (log z base)\n" +
            "Library: (scheme inexact)\n" +
            "Description: Returns the natural logarithm of z, or the logarithm of z to base if given.\n" +
            "Example:\n" +
            "  (log 1.0) => 0.0\n" +
            "  (log 8.0 2.0) => 3.0";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        if (arguments.Length == 2)
            return Math.Log(ToReal(arguments[0]), ToReal(arguments[1]));
        return Math.Log(ToReal(arguments[0]));
    }
}
