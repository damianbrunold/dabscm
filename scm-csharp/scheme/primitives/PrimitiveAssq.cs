namespace scheme;

public class PrimitiveAssq : Primitive
{
    public override string Name()
    {
        return "assq";
    }

    public override string Info()
    {
        return
            "Syntax: (assq key alist)\n" +
            "Library: (scheme base)\n" +
            "Description: Searches association list alist for a pair whose car is eq? to key. Returns the first matching pair, or #f if none is found.\n" +
            "Example:\n" +
            "  (assq 'b '((a 1) (b 2) (c 3))) => (b 2)\n" +
            "  (assq 'd '((a 1) (b 2))) => #f";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        object x = arguments[0];
        object lst = arguments[1];
        while (lst != Value.NIL)
        {
            if (!Value.IsPair(lst)) return false;
            Pair p = Value.AsPair(lst);
            Pair entry = Value.AsPair(p.car);
            if (PrimitiveEqP.Eq(x, entry.car)) return entry;
            lst = p.cdr;
        }
        return false;
    }
}
