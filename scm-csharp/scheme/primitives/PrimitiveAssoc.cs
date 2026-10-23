namespace scheme;

public class PrimitiveAssoc : Primitive
{
    public override string Name()
    {
        return "assoc";
    }

    public override string Info()
    {
        return
            "Syntax: (assoc key alist)\n" +
            "Library: (scheme base)\n" +
            "Description: Searches association list alist for a pair whose car is equal? to key. Returns the first matching pair, or #f if none is found.\n" +
            "Example:\n" +
            "  (assoc \"b\" '((\"a\" 1) (\"b\" 2))) => (\"b\" 2)";
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
            if (PrimitiveEqualP.Equal(x, entry.car)) return entry;
            lst = p.cdr;
        }
        return false;
    }
}
