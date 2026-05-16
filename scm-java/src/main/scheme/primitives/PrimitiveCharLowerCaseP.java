package scheme.primitives;

import scheme.Primitive;
import scheme.Value;
import scheme.SourcePos;

public class PrimitiveCharLowerCaseP extends Primitive {
    @Override
    public String name() {
        return "char-lower-case?";
    }

    @Override
    public String info() {
        return "Syntax: (char-lower-case? char)\n" +
               "Library: (scheme char)\n" +
               "Description: Returns #t if char is a lowercase character.\n" +
               "Example:\n" +
               "  (char-lower-case? #\\a) => #t\n" +
               "  (char-lower-case? #\\A) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Character.isLowerCase(Value.asChar(arguments[0]));
    }
}
