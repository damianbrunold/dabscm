package scheme.primitives;

import scheme.Primitive;
import scheme.Value;
import scheme.SourcePos;

public class PrimitiveCharDowncase extends Primitive {
    @Override
    public String name() {
        return "char-downcase";
    }

    @Override
    public String info() {
        return "Syntax: (char-downcase char)\n" +
               "Library: (scheme char)\n" +
               "Description: Returns the lowercase equivalent of char if it exists, otherwise returns char.\n" +
               "Example:\n" +
               "  (char-downcase #\\A) => #\\a\n" +
               "  (char-downcase #\\a) => #\\a";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Character.toLowerCase(Value.asChar(arguments[0]));
    }
}
