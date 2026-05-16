namespace scheme;

public class PrimitiveCaar : Primitive
{
    public override string Name()
    {
        return "caar";
    }

    public override string Info()
    {
        return
            "Syntax: (caar pair)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the car of the car of pair. Equivalent to (car (car pair)).\n" +
            "Example:\n" +
            "  (caar '((a b) c)) => a";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.AsPair(Value.AsPair(arguments[0]).car).car;
    }
}
