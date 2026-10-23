namespace scheme;

public class PrimitiveAssv : Primitive
{
    public override string Name()
    {
        return "assv";
    }

    public override string Info()
    {
        return
            "Syntax: (assv key alist)\n" +
            "Library: (scheme base)\n" +
            "Description: Searches association list alist for a pair whose car is eqv? to key. Returns the first matching pair, or #f if none is found.\n" +
            "Example:\n" +
            "  (assv 2 '((1 a) (2 b) (3 c))) => (2 b)\n" +
            "  (assv 5 '((1 a) (2 b))) => #f";
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
            if (PrimitiveEqvP.Eqv(x, entry.car)) return entry;
            lst = p.cdr;
        }
        return false;
    }
}
