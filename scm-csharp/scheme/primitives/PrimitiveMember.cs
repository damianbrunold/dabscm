namespace scheme;

public class PrimitiveMember : Primitive
{
    public override string Name()
    {
        return "member";
    }

    public override string Info()
    {
        return
            "Syntax: (member obj list)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the first sublist of list whose car is equal? to obj, or #f if no such sublist exists.\n" +
            "Example:\n" +
            "  (member 'b '(a b c)) => (b c)\n" +
            "  (member 'd '(a b c)) => #f";
    }

    //(define (member x ls)
    //  (if (or (null? ls) (not (pair? ls)))
    //      #f
    //      (if (equal? x (first ls))
    //          ls
    //          (member x (cdr ls)))))
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        object x = arguments[0];
        object lst = arguments[1];
        while (lst != Value.NIL)
        {
            if (!Value.IsPair(lst)) return false;
            Pair p = Value.AsPair(lst);
            if (PrimitiveEqualP.Equal(x, p.car)) return p;
            lst = p.cdr;
        }
        return false;
    }
}
