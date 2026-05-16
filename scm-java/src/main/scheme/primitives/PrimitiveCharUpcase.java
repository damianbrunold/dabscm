package scheme.primitives;

import scheme.Primitive;
import scheme.Value;
import scheme.SourcePos;

public class PrimitiveCharUpcase extends Primitive {
    @Override
    public String name() {
        return "char-upcase";
    }

    @Override
    public String info() {
        return "Syntax: (char-upcase char)\n" +
               "Library: (scheme char)\n" +
               "Description: Returns the uppercase equivalent of char if it exists, otherwise returns char.\n" +
               "Example:\n" +
               "  (char-upcase #\\a) => #\\A\n" +
               "  (char-upcase #\\A) => #\\A";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Character.toUpperCase(Value.asChar(arguments[0]));
    }
}
