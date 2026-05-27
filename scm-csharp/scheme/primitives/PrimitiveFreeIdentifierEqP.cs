namespace scheme;

public class PrimitiveFreeIdentifierEqP : Primitive
{
    private readonly Modules modules;

    public PrimitiveFreeIdentifierEqP(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "free-identifier=?";
    }

    public override string Info()
    {
        return
            "Syntax: (free-identifier=? id1 id2)\n" +
            "Library: (scm core)\n" +
            "Description: Returns #t if the two identifier syntax objects would resolve to " +
            "the same binding (i.e., they are free-identifier=? per R7RS 4.3.2).\n" +
            "Example:\n" +
            "  (free-identifier=? (syntax car) (syntax car)) => #t";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        if (arguments[0] is SyntaxObject a && arguments[1] is SyntaxObject b)
            return SyntaxObject.FreeIdEq(a, b, modules.BindingTable) ? Value.T : Value.F;
        // Fallback: plain symbols compare by name
        if (Value.IsSymbol(arguments[0]) && Value.IsSymbol(arguments[1]))
            return Value.AsSymbol(arguments[0]) == Value.AsSymbol(arguments[1]) ? Value.T : Value.F;
        return Value.F;
    }
}
