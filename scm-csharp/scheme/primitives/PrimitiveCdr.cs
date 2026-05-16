namespace scheme;

public class PrimitiveCdr : Primitive
{
    public override string Name()
    {
        return "cdr";
    }

    public override string Info()
    {
        return
            "Syntax: (cdr pair)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the cdr of pair. It is an error if pair is not a pair.\n" +
            "Example:\n" +
            "  (cdr '((a) b c)) => (b c)\n" +
            "  (cdr '(1 . 2)) => 2";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.AsPair(arguments[0]).cdr;
    }
}
