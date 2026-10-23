namespace scheme;

public class PrimitiveReverse : Primitive
{
    public override string Name()
    {
        return "reverse";
    }

    public override string Info()
    {
        return
            "Syntax: (reverse list)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns a newly allocated list containing the elements of list in reverse order.\n" +
            "Example:\n" +
            "  (reverse '(1 2 3)) => (3 2 1)\n" +
            "  (reverse '()) => ()";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        object lst = arguments[0];
        object acc = Value.NIL;
        while (lst != Value.NIL)
        {
            Pair p = Value.AsPair(lst);
            acc = new Pair(p.car, acc);
            lst = p.cdr;
        }
        return acc;
    }
}
