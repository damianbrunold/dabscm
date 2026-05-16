namespace scheme;

public class PrimitiveCar : Primitive
{
    public override string Name()
    {
        return "car";
    }

    public override string Info()
    {
        return
            "Syntax: (car pair)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the car of pair. It is an error if pair is not a pair.\n" +
            "Example:\n" +
            "  (car '(a b c)) => a\n" +
            "  (car '((a) b)) => (a)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.AsPair(arguments[0]).car;
    }
}
