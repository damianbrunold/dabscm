package scheme.primitives;

import scheme.Primitive;
import scheme.Value;
import scheme.SourcePos;

public class PrimitiveCharFoldcase extends Primitive {
    @Override
    public String name() {
        return "char-foldcase";
    }

    @Override
    public String info() {
        return "Syntax: (char-foldcase char)\n" +
               "Library: (scheme char)\n" +
               "Description: Returns the case-folded equivalent of char (for case-insensitive comparisons). Applies Unicode full case folding.\n" +
               "Example:\n" +
               "  (char-foldcase #\\A) => #\\a\n" +
               "  (char-foldcase #\\a) => #\\a";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Character.toLowerCase(Value.asChar(arguments[0]));
    }
}
