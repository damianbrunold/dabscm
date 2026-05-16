package scheme.primitives;

import scheme.*;

public class PrimitiveFreeIdentifierEqP extends Primitive {
    private final Modules modules;

    public PrimitiveFreeIdentifierEqP(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() { return "free-identifier=?"; }

    @Override
    public String info() {
        return "Syntax: (free-identifier=? id1 id2)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if the two identifier syntax objects would resolve to " +
               "the same binding (i.e., they are free-identifier=? per R7RS 4.3.2).\n" +
               "Example:\n" +
               "  (free-identifier=? (syntax car) (syntax car)) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        if (arguments[0] instanceof SyntaxObject && arguments[1] instanceof SyntaxObject)
            return SyntaxObject.freeIdEq((SyntaxObject) arguments[0], (SyntaxObject) arguments[1],
                modules.getBindingTable())
                ? Value.T : Value.F;
        // Fallback: plain symbols compare by name
        if (Value.isSymbol(arguments[0]) && Value.isSymbol(arguments[1]))
            return Value.asSymbol(arguments[0]) == Value.asSymbol(arguments[1]) ? Value.T : Value.F;
        return Value.F;
    }
}
