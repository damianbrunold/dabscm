package scheme.primitives;

import scheme.Primitive;
import scheme.Value;
import scheme.SourcePos;

public class PrimitiveCharNumericP extends Primitive {
    @Override
    public String name() {
        return "char-numeric?";
    }

    @Override
    public String info() {
        return "Syntax: (char-numeric? char)\n" +
               "Library: (scheme char)\n" +
               "Description: Returns #t if char is a numeric character (digit).\n" +
               "Example:\n" +
               "  (char-numeric? #\\5) => #t\n" +
               "  (char-numeric? #\\a) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Character.isDigit(Value.asChar(arguments[0]));
    }
}
