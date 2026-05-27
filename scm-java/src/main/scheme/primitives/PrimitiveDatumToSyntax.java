package scheme.primitives;

import scheme.*;

public class PrimitiveDatumToSyntax extends Primitive {
    @Override
    public String name() { return "datum->syntax"; }

    @Override
    public String info() {
        return "Syntax: (datum->syntax template-id datum)\n" +
               "Library: (scm core)\n" +
               "Description: Converts datum to a syntax object with the same lexical context " +
               "(wraps) as template-id. This allows the datum to be treated as if it appeared " +
               "in the same scope as the template identifier, enabling intentional hygiene-breaking.\n" +
               "Example:\n" +
               "  (datum->syntax (syntax here) 'x) => #<syntax x>";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        Object templateId = arguments[0];
        Object datum = arguments[1];

        ScopeSet scopes = ScopeSet.EMPTY;
        if (templateId instanceof SyntaxObject)
            scopes = ((SyntaxObject) templateId).scopes;

        return SyntaxObject.wrapDatum(datum, scopes, pos);
    }
}
