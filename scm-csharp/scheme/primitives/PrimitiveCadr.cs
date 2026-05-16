namespace scheme;

public class PrimitiveCadr : Primitive
{
    public override string Name()
    {
        return "cadr";
    }

    public override string Info()
    {
        return
            "Syntax: (cadr pair)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the car of the cdr of pair. Equivalent to (car (cdr pair)).\n" +
            "Example:\n" +
            "  (cadr '(a b c)) => b";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.AsPair(Value.AsPair(arguments[0]).cdr).car;
    }
}
