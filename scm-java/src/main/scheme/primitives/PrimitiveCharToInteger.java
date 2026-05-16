package scheme.primitives;

import scheme.Primitive;
import scheme.Value;
import scheme.SourcePos;

public class PrimitiveCharToInteger extends Primitive {
    @Override
    public String name() {
        return "char->integer";
    }

    @Override
    public String info() {
        return "Syntax: (char->integer char)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the Unicode scalar value (codepoint) of the given character as an exact integer.\n" +
               "Example:\n" +
               "  (char->integer #\\a) => 97\n" +
               "  (char->integer #\\A) => 65";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return (long) Value.asChar(arguments[0]);
    }
}
