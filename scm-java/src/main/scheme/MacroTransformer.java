package scheme;

/**
 * Represents a macro transformer binding (e.g., from define-syntax).
 * Wraps the actual transformer (currently SyntaxRulesTransformer, but
 * extensible to syntax-case and other transformer types in the future).
 */
public class MacroTransformer {
    public final Object transformer;
    public final String docstring;

    public MacroTransformer(Object transformer, String docstring) {
        this.transformer = transformer;
        this.docstring = docstring;
    }

    public MacroTransformer(Object transformer) {
        this(transformer, null);
    }

    @Override
    public String toString() {
        return "#<macro>";
    }
}
