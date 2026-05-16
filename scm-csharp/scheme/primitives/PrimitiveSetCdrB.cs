namespace scheme;

public class PrimitiveSetCdrB : Primitive
{
    public override string Name()
    {
        return "set-cdr!";
    }

    public override string Info()
    {
        return
            "Syntax: (set-cdr! pair obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Stores obj in the cdr field of pair. It is an error if pair is not a pair.\n" +
            "Example:\n" +
            "  (define p (list 1 2 3))\n" +
            "  (set-cdr! p '(b c))\n" +
            "  p => (1 b c)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        Value.AsPair(arguments[0]).cdr = arguments[1];
        return new Values();
    }
}
