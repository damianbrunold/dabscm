namespace scheme;

public class PrimitiveRealP : Primitive
{
    public override string Name()
    {
        return "real?";
    }

    public override string Info()
    {
        return
            "Syntax: (real? obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is a real number, otherwise returns #f. Integers and rationals are also real numbers.\n" +
            "Example:\n" +
            "  (real? 3) => #t\n" +
            "  (real? 3.5) => #t\n" +
            "  (real? 1/3) => #t\n" +
            "  (real? \"hello\") => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsReal(arguments[0]) || Value.IsInteger(arguments[0]) || Value.IsRational(arguments[0]);
    }
}
