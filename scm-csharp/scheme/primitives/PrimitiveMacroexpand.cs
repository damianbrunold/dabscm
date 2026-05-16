namespace scheme;

public class PrimitiveMacroexpand : Primitive
{
    private readonly Modules modules;

    public PrimitiveMacroexpand(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "macroexpand";

    public override string Info() =>
        "Syntax: (macroexpand expr)\n" +
        "Library: (scm core)\n" +
        "Description: Fully expands all macros in expr using the Dybvig expander.\n" +
        "Returns a plain S-expression with all macros expanded.\n" +
        "Example:\n" +
        "  (macroexpand '(and 1 2 3)) => (if 1 (and 2 3) #f)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var expander = new Expander(modules);
        object expanded = expander.Expand(pos ?? new SourcePos("<macroexpand>", 0, 0), arguments[0]);
        return SyntaxObject.Strip(expanded);
    }
}
