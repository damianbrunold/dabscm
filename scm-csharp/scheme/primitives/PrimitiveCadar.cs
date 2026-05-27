namespace scheme;

public class PrimitiveCadar : Primitive
{
    public override string Name()
    {
        return "cadar";
    }

    public override string Info()
    {
        return
            "Syntax: (cadar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Returns the car of the cdr of the car of pair. Equivalent to (car (cdr (car pair))).\n" +
            "Example:\n" +
            "  (cadar '((a b) c)) => b";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        return Value.AsPair(Value.AsPair(Value.AsPair(arguments[0]).car).cdr).car;
    }
}
