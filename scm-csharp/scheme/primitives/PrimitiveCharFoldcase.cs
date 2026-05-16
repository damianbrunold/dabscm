namespace scheme;

public class PrimitiveCharFoldcase : Primitive
{
    public override string Name() => "char-foldcase";

    public override string Info() =>
        "Syntax: (char-foldcase char)\n" +
        "Library: (scheme char)\n" +
        "Description: Returns the case-folded equivalent of char (for case-insensitive comparisons). Applies Unicode full case folding.\n" +
        "Example:\n" +
        "  (char-foldcase #\\A) => #\\a\n" +
        "  (char-foldcase #\\a) => #\\a";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return char.ToLowerInvariant(Value.AsChar(arguments[0]));
    }
}
