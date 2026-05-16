package scheme.primitives;

import scheme.Primitive;
import scheme.Value;
import scheme.SourcePos;

public class PrimitiveCharUpperCaseP extends Primitive {
    @Override
    public String name() {
        return "char-upper-case?";
    }

    @Override
    public String info() {
        return "Syntax: (char-upper-case? char)\n" +
               "Library: (scheme char)\n" +
               "Description: Returns #t if char is an uppercase character.\n" +
               "Example:\n" +
               "  (char-upper-case? #\\A) => #t\n" +
               "  (char-upper-case? #\\a) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Character.isUpperCase(Value.asChar(arguments[0]));
    }
}
