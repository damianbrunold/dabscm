namespace scheme;

public class PrimitiveCons : Primitive
{
    public override string Name()
    {
        return "cons";
    }

    public override string Info()
    {
        return
            "Syntax: (cons obj1 obj2)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns a newly allocated pair whose car is obj1 and whose cdr is obj2.\n" +
            "Example:\n" +
            "  (cons 'a '()) => (a)\n" +
            "  (cons 'a '(b c)) => (a b c)\n" +
            "  (cons 1 2) => (1 . 2)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        return new Pair(arguments[0], arguments[1]);
    }
}
