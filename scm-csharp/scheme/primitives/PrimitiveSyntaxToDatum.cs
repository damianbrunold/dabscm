namespace scheme;

public class PrimitiveSyntaxToDatum : Primitive
{
    public override string Name()
    {
        return "syntax->datum";
    }

    public override string Info()
    {
        return
            "Syntax: (syntax->datum stx)\n" +
            "Library: (scm core)\n" +
            "Description: Strips all syntactic information from stx, returning the underlying datum. " +
            "Identifiers are converted to their symbolic names. Pairs and vectors are recursively stripped.\n" +
            "Example:\n" +
            "  (syntax->datum (syntax foo)) => foo";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return SyntaxObject.Strip(arguments[0]);
    }
}
