namespace scheme;

public class PrimitiveBoundIdentifierEqP : Primitive
{
    public override string Name()
    {
        return "bound-identifier=?";
    }

    public override string Info()
    {
        return
            "Syntax: (bound-identifier=? id1 id2)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if the two identifier syntax objects have the same name " +
            "and the same marks (i.e., they would bind the same variable if one appeared in " +
            "a binding position and the other in a reference position).\n" +
            "Example:\n" +
            "  (bound-identifier=? (syntax x) (syntax x)) => #t";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        if (arguments[0] is SyntaxObject a && arguments[1] is SyntaxObject b)
            return SyntaxObject.BoundIdEq(a, b) ? Value.T : Value.F;
        // Fallback: plain symbols compare by name
        if (Value.IsSymbol(arguments[0]) && Value.IsSymbol(arguments[1]))
            return Value.AsSymbol(arguments[0]) == Value.AsSymbol(arguments[1]) ? Value.T : Value.F;
        return Value.F;
    }
}
