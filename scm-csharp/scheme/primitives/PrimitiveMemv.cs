namespace scheme;

public class PrimitiveMemv : Primitive
{
    public override string Name()
    {
        return "memv";
    }

    public override string Info()
    {
        return
            "Syntax: (memv obj list)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the first sublist of list whose car is eqv? to obj, or #f if no such sublist exists.\n" +
            "Example:\n" +
            "  (memv 2 '(1 2 3)) => (2 3)\n" +
            "  (memv 5 '(1 2 3)) => #f";
    }

    //(define (memv x ls)
    //  (if (or (null? ls) (not (pair? ls)))
    //      #f
    //      (if (eqv? x (first ls))
    //          ls
    //          (memv x (cdr ls)))))
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        object x = arguments[0];
        object lst = arguments[1];
        while (lst != Value.NIL)
        {
            if (!Value.IsPair(lst)) return false;
            Pair p = Value.AsPair(lst);
            if (PrimitiveEqvP.Eqv(x, p.car)) return p;
            lst = p.cdr;
        }
        return false;
    }
}
