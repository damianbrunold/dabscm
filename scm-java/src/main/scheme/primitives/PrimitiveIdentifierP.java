package scheme.primitives;

import scheme.*;

public class PrimitiveIdentifierP extends Primitive {
    @Override
    public String name() { return "identifier?"; }

    @Override
    public String info() {
        return "Syntax: (identifier? obj)\n" +
               "Library: (scm core)\n" +
               "Description: Returns #t if obj is a syntax object wrapping a symbol (an identifier), #f otherwise.\n" +
               "Example:\n" +
               "  (identifier? (syntax foo)) => #t\n" +
               "  (identifier? 42) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (arguments[0] instanceof SyntaxObject) {
            SyntaxObject stx = (SyntaxObject) arguments[0];
            if (stx.isIdentifier())
                return Value.T;
        }
        return Value.F;
    }
}
