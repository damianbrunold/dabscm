namespace scheme;

public class PrimitivePairP : Primitive
{
    public override string Name()
    {
        return "pair?";
    }

    public override string Info()
    {
        return
            "Syntax: (pair? obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is a pair, otherwise returns #f.\n" +
            "Example:\n" +
            "  (pair? '(a b c)) => #t\n" +
            "  (pair? '()) => #f\n" +
            "  (pair? '(a . b)) => #t\n" +
            "  (pair? 7) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsPair(arguments[0]);
    }
}
