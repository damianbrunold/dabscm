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
        long n = arguments[0] instanceof Long ? (Long) arguments[0] : -1;
        if (n < 0 || n > 0x10FFFF) throw new SchemeError(pos, "integer->char: not a code point", arguments[0]);
        // characters are UTF-16 code units here: no silent truncation
        if (n > 0xFFFF) throw new SchemeError(pos, "integer->char: characters beyond U+FFFF are not supported", arguments[0]);
        return (char) n;
    }
}
