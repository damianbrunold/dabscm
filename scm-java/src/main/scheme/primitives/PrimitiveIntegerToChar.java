package scheme.primitives;

import scheme.*;

public class PrimitiveIntegerToChar extends Primitive {
    @Override
    public String name() {
        return "integer->char";
    }

    @Override
    public String info() {
        return "Syntax: (integer->char n)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the character corresponding to the given Unicode scalar value (codepoint).\n" +
               "Example:\n" +
               "  (integer->char 97) => #\\a\n" +
               "  (integer->char 65) => #\\A";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return (char) IntegerMath.toInt(arguments[0]);
    }
}
