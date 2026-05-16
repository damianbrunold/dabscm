package scheme.primitives;

import scheme.*;

public class PrimitiveStringRef extends Primitive {
    @Override
    public String name() {
        return "string-ref";
    }

    @Override
    public String info() {
        return "Syntax: (string-ref s k)\n" +
               "Library: (scheme base) (srfi 13)\n" +
               "Description: Returns the character at index k in the string s. It is an error if k is out of range.\n" +
               "Example:\n" +
               "  (string-ref \"hello\" 0) => #\\h\n" +
               "  (string-ref \"hello\" 4) => #\\o";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        return Value.asString(arguments[0])[(int) (long) arguments[1]];
    }
}
