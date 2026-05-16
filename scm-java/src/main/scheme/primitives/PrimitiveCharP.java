package scheme.primitives;

import scheme.Primitive;
import scheme.Value;
import scheme.SourcePos;

public class PrimitiveCharP extends Primitive {
    @Override
    public String name() {
        return "char?";
    }

    @Override
    public String info() {
        return "Syntax: (char? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is a character, otherwise returns #f.\n" +
               "Example:\n" +
               "  (char? #\\a) => #t\n" +
               "  (char? \"a\") => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isChar(arguments[0]);
    }
}
