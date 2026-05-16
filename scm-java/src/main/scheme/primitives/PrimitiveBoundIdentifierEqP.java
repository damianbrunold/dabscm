package scheme.primitives;

import scheme.*;

public class PrimitiveBoundIdentifierEqP extends Primitive {
    @Override
    public String name() { return "bound-identifier=?"; }

    @Override
    public String info() {
        return "Syntax: (bound-identifier=? id1 id2)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if the two identifier syntax objects have the same name " +
               "and the same marks (i.e., they would bind the same variable if one appeared in " +
               "a binding position and the other in a reference position).\n" +
               "Example:\n" +
               "  (bound-identifier=? (syntax x) (syntax x)) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        if (arguments[0] instanceof SyntaxObject && arguments[1] instanceof SyntaxObject)
            return SyntaxObject.boundIdEq((SyntaxObject) arguments[0], (SyntaxObject) arguments[1])
                ? Value.T : Value.F;
        // Fallback: plain symbols compare by name
        if (Value.isSymbol(arguments[0]) && Value.isSymbol(arguments[1]))
            return Value.asSymbol(arguments[0]) == Value.asSymbol(arguments[1]) ? Value.T : Value.F;
        return Value.F;
    }
}
