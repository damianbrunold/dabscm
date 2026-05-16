namespace scheme;

public class PrimitiveDatumToSyntax : Primitive
{
    public override string Name()
    {
        return "datum->syntax";
    }

    public override string Info()
    {
        return
            "Syntax: (datum->syntax template-id datum)\n" +
            "Library: (scheme base)\n" +
            "Description: Converts datum to a syntax object with the same lexical context " +
            "(wraps) as template-id. This allows the datum to be treated as if it appeared " +
            "in the same scope as the template identifier, enabling intentional hygiene-breaking.\n" +
            "Example:\n" +
            "  (datum->syntax (syntax here) 'x) => #<syntax x>";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        object templateId = arguments[0];
        object datum = arguments[1];

        ScopeSet scopes = ScopeSet.Empty;
        if (templateId is SyntaxObject stx)
            scopes = stx.Scopes;

        return SyntaxObject.WrapDatum(datum, scopes, pos);
    }
}
