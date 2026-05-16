namespace scheme;

public class PrimitiveListP : Primitive
{
    public override string Name() => "list?";

    public override string Info() =>
        "Syntax: (list? obj)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns #t if obj is a proper list (a sequence of pairs terminated by the empty list), otherwise returns #f. Also detects circular lists.\n" +
        "Example:\n" +
        "  (list? '(a b c)) => #t\n" +
        "  (list? '(a . b)) => #f\n" +
        "  (list? '()) => #t";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        // Floyd's cycle detection (tortoise and hare)
        var hare = arguments[0];
        var tortoise = arguments[0];
        while (true)
        {
            if (!Value.IsPair(hare) || hare == Value.NIL) return hare == Value.NIL;
            hare = Value.AsPair(hare).cdr;
            if (!Value.IsPair(hare) || hare == Value.NIL) return hare == Value.NIL;
            hare = Value.AsPair(hare).cdr;
            tortoise = Value.AsPair(tortoise).cdr;
            if (ReferenceEquals(hare, tortoise)) return false;
        }
    }
}
