namespace scheme;

public class PrimitiveNot : Primitive
{
    public override string Name()
    {
        return "not";
    }

    public override string Info()
    {
        return
            "Syntax: (not obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is #f, otherwise returns #f.\n" +
            "Example:\n" +
            "  (not #f) => #t\n" +
            "  (not #t) => #f\n" +
            "  (not 42) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (arguments[0].Equals(Value.F)) return Value.T;
        else return Value.F;
    }
}
