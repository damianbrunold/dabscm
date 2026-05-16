package scheme.primitives;

import scheme.*;

public class PrimitiveStringLength extends Primitive {
    @Override
    public String name() {
        return "string-length";
    }

    @Override
    public String info() {
        return "Syntax: (string-length s)\n" +
               "Library: (scheme base) (srfi 13)\n" +
               "Description: Returns the number of characters in the string s.\n" +
               "Example:\n" +
               "  (string-length \"hello\") => 5\n" +
               "  (string-length \"\") => 0";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return (long) Value.asString(arguments[0]).length;
    }
}
