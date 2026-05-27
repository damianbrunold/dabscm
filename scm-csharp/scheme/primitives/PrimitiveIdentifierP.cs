namespace scheme;

public class PrimitiveIdentifierP : Primitive
{
    public override string Name()
    {
        return "identifier?";
    }

    public override string Info()
    {
        return
            "Syntax: (identifier? obj)\n" +
            "Library: (scm core)\n" +
            "Description: Returns #t if obj is a syntax object wrapping a symbol (an identifier), #f otherwise.\n" +
            "Example:\n" +
            "  (identifier? (syntax foo)) => #t\n" +
            "  (identifier? 42) => #f";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (arguments[0] is SyntaxObject stx && stx.IsIdentifier)
            return Value.T;
        return Value.F;
    }
}
