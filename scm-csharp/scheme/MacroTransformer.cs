namespace scheme;

/// <summary>
/// Represents a macro transformer binding (e.g., from define-syntax).
/// Wraps the actual transformer (currently SyntaxRulesTransformer, but
/// extensible to syntax-case and other transformer types in the future).
/// </summary>
public class MacroTransformer
{
    public readonly object Transformer;
    public readonly string? Docstring;

    public MacroTransformer(object transformer, string? docstring = null)
    {
        this.Transformer = transformer;
        this.Docstring = docstring;
    }

    public override string ToString()
    {
        return "#<macro>";
    }
}
