package scheme.primitives;

import scheme.Primitive;
import scheme.Value;
import scheme.SourcePos;

public class PrimitiveCharAlphabeticP extends Primitive {
    @Override
    public String name() {
        return "char-alphabetic?";
    }

    @Override
    public String info() {
        return "Syntax: (char-alphabetic? char)\n" +
               "Library: (scheme char)\n" +
               "Description: Returns #t if char is an alphabetic character.\n" +
               "Example:\n" +
               "  (char-alphabetic? #\\a) => #t\n" +
               "  (char-alphabetic? #\\1) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Character.isAlphabetic(Value.asChar(arguments[0]));
    }
}
