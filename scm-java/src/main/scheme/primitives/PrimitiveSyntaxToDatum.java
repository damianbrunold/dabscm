package scheme.primitives;

import scheme.*;

public class PrimitiveSyntaxToDatum extends Primitive {
    @Override
    public String name() { return "syntax->datum"; }

    @Override
    public String info() {
        return "Syntax: (syntax->datum stx)\n" +
               "Library: (scheme base)\n" +
               "Description: Strips all syntactic information from stx, returning the underlying datum. " +
               "Identifiers are converted to their symbolic names. Pairs and vectors are recursively stripped.\n" +
               "Example:\n" +
               "  (syntax->datum (syntax foo)) => foo";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return SyntaxObject.strip(arguments[0]);
    }
}
